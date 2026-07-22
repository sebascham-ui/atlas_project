import {
  workflow,
  node,
  trigger,
  sticky,
  newCredential,
  ifElse,
  switchCase,
  languageModel,
  outputParser,
  expr
} from '@n8n/workflow-sdk';

// =====================================================================
// ATLAS - Recepción de Reservaciones (v2)
// Flujo 1: correo -> interpretación IA -> Supabase -> respuesta automática
// =====================================================================

const SUPABASE_RPC_BASE = 'https://kdtagfclulhupxkuojhx.supabase.co/rest/v1/rpc';

// ---------------------------------------------------------------------
// TRIGGER: nuevo correo no leído en Outlook
// ---------------------------------------------------------------------

const outlookTrigger = trigger({
  type: 'n8n-nodes-base.microsoftOutlookTrigger',
  version: 1,
  config: {
    name: 'Nuevo Correo Recibido',
    parameters: {
      event: 'messageReceived',
      output: 'raw',
      pollTimes: { item: [{ mode: 'everyX', value: 5, unit: 'minutes' }] },
      filters: {
        readStatus: 'unread',
        // Restringido a Bandeja de entrada. Sin esto, el nodo también
        // captura correos de Correo no deseado y otras carpetas.
        foldersToInclude: ['AAMkAGU0ZDY4MmU0LWM5MWItNGRlMi04NDQ1LTBjODAzZmUyMjgyYwAuAAAAAAAomVopnVXXTp6t621h7TrWAQBhJndSq5ZNSacDeJ63R-5xAAAAAAEMAAA=']
      },
      options: { downloadAttachments: false }
    },
    credentials: { microsoftOutlookOAuth2Api: newCredential('Microsoft Outlook account') }
  },
  output: [
    {
      id: 'AAMkAGI1AAA=',
      conversationId: 'AAQkAGI1AAA=',
      internetMessageId: '<abc123@clientedominio.com>',
      subject: 'Reservación traslado aeropuerto 15 agosto',
      from: { emailAddress: { address: 'cliente@example.com', name: 'Juan Pérez' } },
      body: { contentType: 'html', content: '<html><body><p>Buenas tardes, quisiera reservar un traslado...</p></body></html>' },
      bodyPreview: 'Buenas tardes, quisiera reservar un traslado...',
      receivedDateTime: '2026-07-21T15:00:00Z',
      isRead: false
    }
  ]
});

// ---------------------------------------------------------------------
// CODE: limpiar el correo (quitar HTML, firmas, disclaimers)
// ---------------------------------------------------------------------

const cleanEmail = node({
  type: 'n8n-nodes-base.code',
  version: 2,
  config: {
    name: 'Limpiar Correo',
    parameters: {
      mode: 'runOnceForEachItem',
      language: 'javaScript',
      jsCode:
        "const msg = $json;\n" +
        "\n" +
        "const rawHtml = (msg.body && msg.body.content) || msg.bodyPreview || '';\n" +
        "\n" +
        "let text = rawHtml\n" +
        "  .replace(/<style[\\s\\S]*?<\\/style>/gi, '')\n" +
        "  .replace(/<script[\\s\\S]*?<\\/script>/gi, '')\n" +
        "  .replace(/<br\\s*\\/?>/gi, '\\n')\n" +
        "  .replace(/<\\/p>/gi, '\\n')\n" +
        "  .replace(/<[^>]+>/g, '')\n" +
        "  .replace(/&nbsp;/g, ' ')\n" +
        "  .replace(/&amp;/g, '&')\n" +
        "  .replace(/&lt;/g, '<')\n" +
        "  .replace(/&gt;/g, '>')\n" +
        "  .replace(/&quot;/g, '\"')\n" +
        "  .replace(/&#39;/g, \"'\");\n" +
        "\n" +
        // Ronda 11 (2026-07-22): tras prueba real de continuación (ver hilo con
        // folio AT-20260722-000002), se descubrió que las respuestas de Gmail/
        // Outlook incluyen el correo anterior COMPLETO citado debajo del texto
        // nuevo ("El ... escribió:" / "On ... wrote:" / bloques "De:/Enviado:"
        // de Outlook) -- sin cortarlo, la IA de extracción reprocesaba TODO el
        // correo anterior como si fuera contenido nuevo en cada respuesta,
        // duplicando servicios completos. Estos patrones cortan la cita citada,
        // dejando solo lo que el cliente escribió realmente en este mensaje.
        "// -- cortar cadenas de correo citado (Gmail/Outlook) --\n" +
        "const cutMarkers = [\n" +
        "  /\\r?\\n\\s*El\\s+[^\\n]{0,120}escribi[oó]:\\s*\\r?\\n[\\s\\S]*/i,\n" +
        "  /\\r?\\n\\s*On\\s+[^\\n]{0,120}wrote:\\s*\\r?\\n[\\s\\S]*/i,\n" +
        "  /\\r?\\n\\s*De:\\s*[^\\n]*\\r?\\n\\s*Enviado:[\\s\\S]*/i,\n" +
        "  /\\r?\\n\\s*From:\\s*[^\\n]*\\r?\\n\\s*Sent:[\\s\\S]*/i,\n" +
        "  /\\r?\\n-{2,}\\s*(Mensaje original|Original Message)\\s*-{2,}[\\s\\S]*/i,\n" +
        "  /este correo[\\s\\S]*confidencial[\\s\\S]*/i,\n" +
        "  /this email[\\s\\S]*confidential[\\s\\S]*/i,\n" +
        "  /aviso de confidencialidad[\\s\\S]*/i,\n" +
        "  /enviado desde mi (iphone|correo|tel[eé]fono)[\\s\\S]*/i\n" +
        "];\n" +
        "for (const marker of cutMarkers) {\n" +
        "  text = text.replace(marker, '');\n" +
        "}\n" +
        "\n" +
        "text = text.replace(/\\n{3,}/g, '\\n\\n').trim();\n" +
        "\n" +
        "return {\n" +
        "  json: {\n" +
        "    messageId: msg.id,\n" +
        "    conversationId: msg.conversationId,\n" +
        "    internetMessageId: msg.internetMessageId,\n" +
        "    subject: msg.subject || '(sin asunto)',\n" +
        "    fromEmail: (msg.from && msg.from.emailAddress && msg.from.emailAddress.address) || '',\n" +
        "    fromName: (msg.from && msg.from.emailAddress && msg.from.emailAddress.name) || '',\n" +
        "    receivedDateTime: msg.receivedDateTime,\n" +
        "    cleanBody: text,\n" +
        "    rawBodyHtml: rawHtml\n" +
        "  }\n" +
        "};\n"
    }
  },
  output: [
    {
      messageId: 'AAMkAGI1AAA=',
      conversationId: 'AAQkAGI1AAA=',
      internetMessageId: '<abc123@clientedominio.com>',
      subject: 'Reservación traslado aeropuerto 15 agosto',
      fromEmail: 'cliente@example.com',
      fromName: 'Juan Pérez',
      receivedDateTime: '2026-07-21T15:00:00Z',
      cleanBody: 'Buenas tardes, quisiera reservar un traslado del aeropuerto de Querétaro a un hotel en San Miguel de Allende para 4 personas el 15 de agosto, vuelo AM123 llegando a las 14:30.',
      rawBodyHtml: '<html><body><p>Buenas tardes, quisiera reservar un traslado...</p></body></html>'
    }
  ]
});

// ---------------------------------------------------------------------
// OUTLOOK: marcar el correo como leído (rama lateral, evita relectura)
// ---------------------------------------------------------------------

const markAsRead = node({
  type: 'n8n-nodes-base.microsoftOutlook',
  version: 2,
  config: {
    name: 'Marcar Correo Como Leído',
    parameters: {
      resource: 'message',
      operation: 'update',
      messageId: { __rl: true, mode: 'id', value: expr('{{ $json.messageId }}') },
      updateFields: { isRead: true }
    },
    credentials: { microsoftOutlookOAuth2Api: newCredential('Microsoft Outlook account') }
  },
  output: [{ id: 'AAMkAGI1AAA=', isRead: true }]
});

// ---------------------------------------------------------------------
// IA: clasificar el correo y extraer los datos de reservación
// ---------------------------------------------------------------------

const extractionModel = languageModel({
  type: '@n8n/n8n-nodes-langchain.lmChatAnthropic',
  version: 1.5,
  config: {
    name: 'Modelo IA (Extracción)',
    parameters: {
      model: { __rl: true, mode: 'list', value: 'claude-haiku-4-5-20251001', cachedResultName: 'Claude Haiku 4.5' },
      options: { maxTokensToSample: 2048 }
    },
    credentials: { anthropicApi: newCredential('Anthropic account') }
  }
});

const extractionParser = outputParser({
  type: '@n8n/n8n-nodes-langchain.outputParserStructured',
  version: 1.3,
  config: {
    name: 'Formato de Extracción',
    parameters: {
      schemaType: 'fromJson',
      jsonSchemaExample: JSON.stringify({
        should_continue: true,
        processing: {
          engine: 'RESERVATION_ENGINE',
          reasoning: 'El cliente solicita un traslado del aeropuerto a su hotel para una fecha específica',
          // Ronda 10 (2026-07-22): separado de should_continue a propósito --
          // should_continue solo distingue "correo real de negocio" vs. spam.
          // Una reservación fuera del área de servicio SIGUE siendo un correo
          // real (should_continue:true), solo que no se procesa 100%
          // automático -- por eso tiene su propia bandera, para que
          // "Enrutar por Tipo de Correo" la mande a Revisión Manual en vez
          // de a la alerta de "correo no procesado" (que es para spam).
          in_service_area: true
        },
        // Ronda 6 (2026-07-22): idioma detectado del correo del cliente.
        // Solo se soportan "es"/"en" por ahora -- se usa para responder
        // en el mismo idioma, tanto en el contenido de la IA como en las
        // etiquetas fijas de la plantilla del correo.
        client_language: 'es',
        client: {
          full_name: 'Juan Pérez',
          email: 'juan.perez@example.com',
          phone: '+52 998 123 4567'
        },
        reservation: {
          priority: 'NORMAL',
          customer_notes: 'Prefiere unidad con aire acondicionado'
        },
        services: [
          {
            direction: 'ARRIVAL',
            service_type: 'TRANSFER',
            origin: 'Aeropuerto Intercontinental de Querétaro (QRO)',
            destination: 'Hotel Real de Minas, San Miguel de Allende',
            scheduled_departure: '2026-08-15T14:30:00-06:00',
            flight_number: 'AM123',
            flight_datetime: '2026-08-15T14:30:00-06:00',
            passenger_count: 4,
            luggage_count: 4,
            // Ronda 11 (2026-07-22): ejemplo actualizado -- client_instructions
            // ahora es SOLO el detalle que no cabe en otro campo (aquí no hay
            // ninguno especial en este ejemplo, por eso queda vacío).
            client_instructions: '',
            // Ronda 8 (2026-07-22): lista explícita de qué le falta a ESTE
            // servicio en particular. Reemplaza la lógica anterior de
            // "inferir lo que falta a partir de si el número es 0 o está
            // vacío", que no distinguía "el cliente no lo mencionó" de "el
            // cliente confirmó que es cero" (ej. "no llevamos equipaje").
            missing_fields: [],
            // Ronda 11 (2026-07-22): nuevo -- pregunta de aclaración puntual,
            // solo si el cliente mencionó algo especial que la amerite (ver
            // guía completa en el systemMessage). Vacío en este ejemplo
            // porque no hay ninguna circunstancia especial que aclarar.
            followup_question: ''
          },
          {
            direction: 'DEPARTURE',
            service_type: 'TRANSFER',
            origin: 'Hotel Real de Minas, San Miguel de Allende',
            destination: 'Aeropuerto Intercontinental de Querétaro (QRO)',
            scheduled_departure: '2026-08-20T09:00:00-06:00',
            flight_number: '',
            flight_datetime: '',
            passenger_count: 4,
            luggage_count: 4,
            client_instructions: 'Viajan con un perro pequeño',
            missing_fields: ['TIME'],
            followup_question: '¿El perro viajará en su transportadora?'
          }
        ]
      })
    }
  }
});

const extractReservation = node({
  type: '@n8n/n8n-nodes-langchain.agent',
  version: 3.1,
  config: {
    name: 'Clasificar y Extraer Reservación',
    parameters: {
      promptType: 'define',
      text: expr(
        'Fecha y hora actuales: {{ $now.toISO() }}\n' +
        'Asunto del correo: {{ $json.subject }}\n' +
        'Remitente: {{ $json.fromName }} <{{ $json.fromEmail }}>\n' +
        'Recibido: {{ $json.receivedDateTime }}\n\n' +
        'Cuerpo del correo:\n{{ $json.cleanBody }}'
      ),
      hasOutputParser: true,
      options: {
        systemMessage:
          'Eres el motor de clasificación y extracción de datos de ATLAS, el sistema interno de ' +
          'Transportes y Tours San Miguel Mágico (empresa familiar de transporte turístico: traslados ' +
          'aeropuerto-hotel, tours, renta con chofer).\n\n' +
          'TU ÚNICO TRABAJO es leer el correo y devolver el JSON estructurado solicitado. Nunca decides ' +
          'lógica de negocio, solo interpretas y transformas.\n\n' +
          'PASO 1 - Clasifica el correo en uno de estos "engines":\n' +
          // Ronda 12 (2026-07-22): tras prueba real, un correo que decía
          // "quisiera COTIZAR un tour" con fecha/personas concretas cayó en
          // INQUIRY_ENGINE (por la palabra "cotizar") en vez de
          // RESERVATION_ENGINE -- y como INQUIRY_ENGINE no tiene
          // procesamiento automático, se fue a Revisión Manual sin
          // necesidad. Para este negocio "cotizar" y "reservar" son
          // básicamente lo mismo en la práctica (así habla la gente
          // normalmente) y la orden de todos modos nace sin confirmar
          // (estado Recibida) -- el equipo la confirma después. Se
          // redefine el criterio: lo que importa es si HAY datos concretos
          // de un viaje que armar, no qué verbo usó el cliente.
          '- RESERVATION_ENGINE: el cliente da datos concretos de un viaje que se pueden convertir en una ' +
          'cotización/reservación (traslado, tour, servicio por horas) -- sin importar si usa la palabra ' +
          '"reservar", "cotizar", "cotización" o similar; para este negocio son equivalentes en la práctica, ' +
          'ya que toda solicitud nace sin confirmar (el equipo la revisa y confirma después). Lo que define ' +
          'este engine es que haya suficiente información de un viaje específico (aunque falten algunos ' +
          'datos, ver missing_fields más abajo) para poder armar al menos un "service".\n' +
          '- UPDATE_ENGINE: el cliente pide modificar o cancelar una reservación ya existente.\n' +
          '- INQUIRY_ENGINE: pregunta genérica SIN datos concretos de un viaje específico (ej. "¿cuánto ' +
          'cobran por un traslado del aeropuerto?" sin fecha ni detalles) -- no hay información suficiente ' +
          'para armar ni un solo "service". Si el cliente menciona fecha, tipo de servicio, o cualquier otro ' +
          'dato concreto de un viaje, usa RESERVATION_ENGINE en vez de este, aunque la pregunta sea sobre precio.\n' +
          '- SUPPLIER_ENGINE: correo de un proveedor/aerolínea/hotel, no de un cliente final.\n' +
          '- INTERNAL_ENGINE: correo interno del equipo, no de un cliente.\n' +
          'Si el correo es spam, publicidad, un rebote automático, "fuera de oficina", o no tiene relación ' +
          'con el negocio, pon should_continue en false y explica por qué en processing.reasoning.\n\n' +
          // Ronda 10 (2026-07-22): el usuario aclaró que la empresa opera desde
          // San Miguel de Allende, Guanajuato -- no todos los correos de
          // reservación que lleguen serán relevantes (ej. alguien pidiendo un
          // traslado 100% dentro de otra ciudad, sin ninguna conexión con San
          // Miguel). Estos casos siguen siendo correos de negocio genuinos
          // (should_continue sigue en true) -- por eso se usa una bandera
          // aparte (processing.in_service_area) para que el switch de abajo
          // los mande a "Revisión Manual" en vez de a la alerta de "correo no
          // procesado" (que es para spam/irrelevante).
          'Además, si el engine es RESERVATION_ENGINE: Transportes y Tours San Miguel Mágico está basada en ' +
          'San Miguel de Allende, Guanajuato, y su área de servicio siempre incluye San Miguel de Allende ' +
          'como origen o destino de AL MENOS UNO de los servicios solicitados (por ejemplo: traslados entre ' +
          'los aeropuertos de Querétaro (QRO) o del Bajío/León (BJX) y San Miguel de Allende, tours dentro o ' +
          'alrededor de la ciudad, o servicios por horas que partan o terminen ahí). Sí se aceptan viajes con ' +
          'destino a otras ciudades o incluso a otros países, siempre y cuando conecten con San Miguel de ' +
          'Allende en alguno de sus puntos. Marca processing.in_service_area en true si al menos un servicio ' +
          'conecta con San Miguel de Allende, o en false si NINGÚN servicio tiene relación con San Miguel de ' +
          'Allende (ni como origen ni como destino) -- en ese caso, should_continue se queda en true (sigue ' +
          'siendo una solicitud real, no spam) y explica en processing.reasoning que está fuera del área de ' +
          'servicio habitual, para que el equipo la revise manualmente antes de decidir si se atiende. Para ' +
          'cualquier otro engine, deja processing.in_service_area en true (no aplica).\n\n' +
          'PASO 2 - Si el engine es RESERVATION_ENGINE, extrae:\n' +
          '- client.full_name, client.email (usa el remitente si el cuerpo no da otro correo), client.phone.\n' +
          '- Un arreglo "services", uno por cada traslado/servicio mencionado. direction debe ser ' +
          '"ARRIVAL" (llegada/recogida en aeropuerto) o "DEPARTURE" (salida/traslado al aeropuerto).\n' +
          '- service_type debe ser EXACTAMENTE uno de estos códigos (nunca texto libre ni descripciones ' +
          'en inglés o español):\n' +
          '  * TRANSFER: traslado sencillo entre dos puntos (incluye TODOS los traslados aeropuerto-hotel, ' +
          'tanto de llegada como de salida; este es el valor por default para reservaciones de traslado).\n' +
          '  * ROUND_TRIP: solo si el cliente pide explícitamente un viaje redondo como UN SOLO servicio ' +
          '(no lo uses para llegada+salida por separado; en ese caso usa dos services con TRANSFER).\n' +
          '  * HOURLY: servicio por horas / renta con chofer por tiempo.\n' +
          '  * TOUR: tour turístico.\n' +
          '- Normaliza fechas relativas ("mañana", "el viernes", "próximo lunes") a fecha absoluta ISO 8601 ' +
          'con zona horaria -06:00 (hora del centro de México / San Miguel de Allende, Guanajuato), usando ' +
          'la fecha actual como referencia.\n' +
          '- Normaliza nombres/códigos de aeropuertos y aerolíneas a su forma completa reconocible.\n' +
          '- Si faltan datos (ej. no dan hora exacta), dejar el campo vacío en vez de inventar información.\n' +
          // Ronda 11 (2026-07-22): tras prueba real, client_instructions se
          // estaba usando como un resumen de TODO el servicio (duplicando
          // hora/ruta/vuelo/pasajeros que ya van en sus propios campos).
          // Se acota explícitamente a SOLO lo que no cabe en otro campo.
          '- client_instructions: ÚNICAMENTE detalles especiales que NO se capturan en ningún otro campo ' +
          '(ejemplos: mascotas, sillas para bebé, equipo especial o voluminoso, restricciones de movilidad, ' +
          'puntos de encuentro fuera de lo normal). NUNCA repitas aquí información que ya va en otro campo -- ' +
          'hora, origen/destino, número de vuelo, o cantidad de pasajeros/maletas -- eso ya se muestra aparte ' +
          'en la plantilla, repetirlo aquí es redundante y confuso para el cliente. Redáctalo TÚ, breve (una ' +
          'frase), en el idioma de client_language (ver PASO 3), aunque el correo original venga en otro ' +
          'idioma. Si el cliente no mencionó ningún detalle especial para ese servicio, deja este campo como ' +
          'cadena vacía "".\n' +
          '- passenger_count y luggage_count: usa 0 SOLO cuando el cliente lo confirme explícitamente (ej. ' +
          '"no llevamos equipaje", "sin maletas") -- 0 es una respuesta completa y válida, no significa que ' +
          'falte el dato. Si el cliente simplemente no menciona el equipaje o el número de pasajeros para ese ' +
          'servicio, dejarlo en 0 igual, pero SIN confirmarlo (ver missing_fields abajo) -- la diferencia entre ' +
          '"confirmado en cero" y "no mencionado" se marca en missing_fields, no en el número.\n' +
          // Ronda 11 (2026-07-22): tras prueba real, la IA agregó por su cuenta
          // un código "PHONE" que no existe en el catálogo aprobado -- el
          // sistema no sabía mostrarlo y terminaba enseñándole al cliente el
          // texto crudo del código. Se refuerza que NUNCA se inventen códigos
          // nuevos, y se explica dónde va lo que sí necesite una pregunta que
          // no encaje en estas 4 categorías (followup_question, abajo).
          '- missing_fields: por cada servicio, arreglo con los datos importantes que el cliente NO ' +
          'proporcionó (y que si hacen falta para operar el servicio). Usa EXCLUSIVAMENTE estos 4 códigos, ' +
          'nunca inventes ni agregues otros: ' +
          '"TIME" (no dio hora exacta), "FLIGHT_NUMBER" (solo aplica a traslados de LLEGADA -- ARRIVAL -- sin ' +
          'número de vuelo; no lo pidas para TOUR, HOURLY, ni traslados de salida), "PASSENGER_COUNT" (no dijo ' +
          'cuántos pasajeros), "LUGGAGE_COUNT" (no dijo nada sobre equipaje, ni siquiera "sin maletas"). Si el ' +
          'cliente ya confirmó un dato (aunque sea con un cero), NO lo incluyas en missing_fields. Deja el ' +
          'arreglo vacío [] si no falta nada relevante para ese servicio. NUNCA agregues un quinto código por ' +
          'tu cuenta (por ejemplo, el teléfono del cliente NO es parte de missing_fields -- client.phone es un ' +
          'campo aparte) -- para cualquier otra aclaración que de verdad amerite pregunta, usa ' +
          'followup_question.\n' +
          '- followup_question: como MÁXIMO una pregunta breve de aclaración operativa por servicio, SOLO si ' +
          'el cliente mencionó una circunstancia especial que amerite confirmar algo puntual -- por ejemplo, ' +
          'si menciona una mascota, preguntar si viajará en su transportadora; si menciona un bebé, preguntar ' +
          'si necesitan silla para bebé en el vehículo; si menciona equipo voluminoso, preguntar sus ' +
          'dimensiones aproximadas. Redáctala TÚ, en el idioma de client_language, como pregunta directa y ' +
          'breve. NUNCA la uses para pedir datos que ya cubre missing_fields (hora, vuelo, pasajeros, ' +
          'equipaje) ni para pedir el teléfono del cliente. Si no hay ninguna circunstancia especial que ' +
          'amerite pregunta, o si el cliente ya la respondió, deja este campo como cadena vacía "".\n' +
          '- reservation.priority es "NORMAL" salvo que el cliente indique urgencia explícita, en cuyo caso "URGENTE".\n\n' +
          'PASO 3 - Detecta client_language: el idioma en el que el CLIENTE escribió el correo (no el idioma ' +
          'del asunto si viene de un sistema automático). Usa "en" si el cuerpo del correo está escrito en ' +
          'inglés, y "es" en cualquier otro caso (incluyendo español, o si no queda claro) -- "es" es el ' +
          'idioma por default del negocio. Este campo se usa para responder al cliente en su propio idioma.\n\n' +
          'Responde ÚNICAMENTE con el JSON solicitado, sin texto adicional.'
      }
    },
    subnodes: { model: extractionModel, outputParser: extractionParser }
  },
  // El nodo Agent con Output Parser estructurado envuelve el resultado
  // parseado dentro de una clave "output" (confirmado en ejecución real
  // el 2026-07-21). El mock de abajo refleja esa forma real.
  output: [
    {
      output: {
        should_continue: true,
        processing: { engine: 'RESERVATION_ENGINE', reasoning: 'Solicitud clara de traslado aeropuerto-hotel' },
        client_language: 'es',
        client: { full_name: 'Juan Pérez', email: 'cliente@example.com', phone: '' },
        reservation: { priority: 'NORMAL', customer_notes: '' },
        services: [
          {
            direction: 'ARRIVAL',
            service_type: 'TRANSFER',
            origin: 'Aeropuerto Intercontinental de Querétaro (QRO)',
            destination: 'Hotel Real de Minas, San Miguel de Allende',
            scheduled_departure: '2026-08-15T14:30:00-06:00',
            flight_number: 'AM123',
            flight_datetime: '2026-08-15T14:30:00-06:00',
            passenger_count: 4,
            luggage_count: 4,
            client_instructions: '',
            missing_fields: []
          }
        ]
      }
    }
  ]
});

// ---------------------------------------------------------------------
// IF: ¿el correo se debe procesar automáticamente?
// ---------------------------------------------------------------------

const ifShouldContinue = ifElse({
  version: 2.3,
  config: {
    name: '¿Debe Continuar?',
    parameters: {
      conditions: {
        combinator: 'and',
        options: { caseSensitive: true, leftValue: '', typeValidation: 'strict' },
        conditions: [
          // El nodo AI Agent con Output Parser estructurado envuelve el JSON
          // parseado dentro de una clave "output" (confirmado en ejecución real).
          { leftValue: expr('{{ $json.output.should_continue }}'), operator: { type: 'boolean', operation: 'true' }, rightValue: true }
        ]
      }
    }
  }
});

// ---------------------------------------------------------------------
// ALERTA: correo no procesado automáticamente (spam / irrelevante)
// ---------------------------------------------------------------------

const alertNotProcessed = node({
  type: 'n8n-nodes-base.httpRequest',
  version: 4.4,
  config: {
    name: 'Alerta - Correo No Procesado',
    parameters: {
      method: 'POST',
      url: SUPABASE_RPC_BASE + '/create_internal_alert',
      sendBody: true,
      contentType: 'json',
      specifyBody: 'json',
      jsonBody: {
        p_notification_type_code: 'ERROR_AUTOMATIZACION',
        p_subject: expr('Correo no procesado automáticamente: {{ $("Limpiar Correo").first().json.subject }}'),
        p_message: expr(
          'Razón: {{ $json.output.processing?.reasoning ?? "sin razón" }}\n' +
          'Remitente: {{ $("Limpiar Correo").first().json.fromEmail }}\n' +
          'Asunto original: {{ $("Limpiar Correo").first().json.subject }}'
        )
      },
      authentication: 'genericCredentialType',
      genericAuthType: 'httpCustomAuth',
      // PostgREST devuelve valores escalares (uuid, boolean) como texto
      // plano, no como JSON válido (p.ej. un uuid sin comillas). Forzar
      // responseFormat:'text' evita que el nodo intente parsear JSON y
      // truene; el texto queda disponible en $json.data (confirmado en
      // ejecución real el 2026-07-21).
      options: { response: { response: { responseFormat: 'text' } } }
    },
    credentials: { httpCustomAuth: newCredential('Supabase Atlas API') }
  },
  output: [{ data: 'a1b2c3d4-0000-0000-0000-000000000000' }]
});

// ---------------------------------------------------------------------
// SWITCH: enrutar por tipo de engine
// ---------------------------------------------------------------------

const switchEngine = switchCase({
  version: 3.4,
  config: {
    name: 'Enrutar por Tipo de Correo',
    parameters: {
      mode: 'rules',
      rules: {
        values: [
          {
            outputKey: 'reservacion',
            conditions: {
              combinator: 'and',
              options: { caseSensitive: true, leftValue: '', typeValidation: 'strict' },
              conditions: [
                { leftValue: expr('{{ $json.output.processing.engine }}'), operator: { type: 'string', operation: 'equals' }, rightValue: 'RESERVATION_ENGINE' },
                // Ronda 10 (2026-07-22): una reservación fuera del área de
                // servicio (ver "Clasificar y Extraer Reservación") NO debe
                // seguir el pipeline 100% automático -- cae al fallback
                // "Revisión Manual" igual que UPDATE_ENGINE/INQUIRY_ENGINE/etc.
                { leftValue: expr('{{ $json.output.processing.in_service_area }}'), operator: { type: 'boolean', operation: 'true' }, rightValue: true }
              ]
            }
          }
        ]
      },
      options: { fallbackOutput: 'extra', renameFallbackOutput: 'Revisión Manual' }
    }
  }
});

// ---------------------------------------------------------------------
// ALERTA: engines no automatizados aún (requieren revisión manual)
// ---------------------------------------------------------------------

const alertManualReview = node({
  type: 'n8n-nodes-base.httpRequest',
  version: 4.4,
  config: {
    name: 'Alerta - Revisión Manual',
    parameters: {
      method: 'POST',
      url: SUPABASE_RPC_BASE + '/create_internal_alert',
      sendBody: true,
      contentType: 'json',
      specifyBody: 'json',
      jsonBody: {
        p_notification_type_code: 'ALERTA_INTERNA',
        p_subject: expr('Revisión manual requerida: {{ $("Limpiar Correo").first().json.subject }}'),
        p_message: expr(
          'Tipo detectado: {{ $json.output.processing?.engine ?? "desconocido" }}\n' +
          'Razón: {{ $json.output.processing?.reasoning ?? "sin detalle" }}\n' +
          'Cliente: {{ $json.output.client?.full_name ?? "desconocido" }}\n' +
          'Remitente: {{ $("Limpiar Correo").first().json.fromEmail }}\n' +
          'Este correo no se procesó automáticamente en Flujo 1 (ver Razón arriba). Revisar manualmente para decidir el siguiente paso.'
        )
      },
      authentication: 'genericCredentialType',
      genericAuthType: 'httpCustomAuth',
      // PostgREST devuelve valores escalares (uuid, boolean) como texto
      // plano, no como JSON válido (p.ej. un uuid sin comillas). Forzar
      // responseFormat:'text' evita que el nodo intente parsear JSON y
      // truene; el texto queda disponible en $json.data (confirmado en
      // ejecución real el 2026-07-21).
      options: { response: { response: { responseFormat: 'text' } } }
    },
    credentials: { httpCustomAuth: newCredential('Supabase Atlas API') }
  },
  output: [{ data: 'b2c3d4e5-0000-0000-0000-000000000000' }]
});

// ---------------------------------------------------------------------
// IF: ¿la extracción trae al menos un servicio?
// ---------------------------------------------------------------------

const ifHasServices = ifElse({
  version: 2.3,
  config: {
    name: '¿Tiene Servicios?',
    parameters: {
      // El comparador "array notEmpty" de n8n intenta convertir el rightValue
      // de relleno ('') al tipo "array" incluso con looseTypeValidation
      // activado, y truena ("the string '' can't be converted to an array").
      // Más simple y robusto: comparar la longitud del arreglo como número.
      conditions: {
        combinator: 'and',
        options: { caseSensitive: true, leftValue: '', typeValidation: 'strict' },
        conditions: [
          { leftValue: expr('{{ $json.output.services.length }}'), operator: { type: 'number', operation: 'gt' }, rightValue: 0 }
        ]
      }
    }
  }
});

// ---------------------------------------------------------------------
// HTTP: buscar o crear la persona (cliente)
// ---------------------------------------------------------------------

const findOrCreatePerson = node({
  type: 'n8n-nodes-base.httpRequest',
  version: 4.4,
  config: {
    name: 'Buscar o Crear Persona',
    parameters: {
      method: 'POST',
      url: SUPABASE_RPC_BASE + '/person',
      sendBody: true,
      contentType: 'json',
      specifyBody: 'json',
      jsonBody: {
        p_client: {
          full_name: expr('{{ $json.output.client.full_name }}'),
          email: expr('{{ $json.output.client.email }}'),
          phone: expr('{{ $json.output.client.phone }}'),
          preferred_language: 'ES'
        }
      },
      authentication: 'genericCredentialType',
      genericAuthType: 'httpCustomAuth',
      // PostgREST devuelve valores escalares (uuid, boolean) como texto
      // plano, no como JSON válido (p.ej. un uuid sin comillas). Forzar
      // responseFormat:'text' evita que el nodo intente parsear JSON y
      // truene; el texto queda disponible en $json.data (confirmado en
      // ejecución real el 2026-07-21).
      options: { response: { response: { responseFormat: 'text' } } }
    },
    credentials: { httpCustomAuth: newCredential('Supabase Atlas API') }
  },
  output: [{ data: 'c3d4e5f6-0000-0000-0000-000000000000' }]
});

// ---------------------------------------------------------------------
// HTTP: buscar o crear la cuenta comercial
// ---------------------------------------------------------------------

const findOrCreateAccount = node({
  type: 'n8n-nodes-base.httpRequest',
  version: 4.4,
  config: {
    name: 'Buscar o Crear Cuenta',
    parameters: {
      method: 'POST',
      url: SUPABASE_RPC_BASE + '/account',
      sendBody: true,
      contentType: 'json',
      specifyBody: 'json',
      jsonBody: {
        p_person_id: expr('{{ $("Buscar o Crear Persona").first().json.data }}'),
        p_account_type_code: 'INDIVIDUAL'
      },
      authentication: 'genericCredentialType',
      genericAuthType: 'httpCustomAuth',
      // PostgREST devuelve valores escalares (uuid, boolean) como texto
      // plano, no como JSON válido (p.ej. un uuid sin comillas). Forzar
      // responseFormat:'text' evita que el nodo intente parsear JSON y
      // truene; el texto queda disponible en $json.data (confirmado en
      // ejecución real el 2026-07-21).
      options: { response: { response: { responseFormat: 'text' } } }
    },
    credentials: { httpCustomAuth: newCredential('Supabase Atlas API') }
  },
  output: [{ data: 'd4e5f6a7-0000-0000-0000-000000000000' }]
});

// ---------------------------------------------------------------------
// HTTP: buscar o crear el hilo de conversación (ligado al conversationId real de Outlook)
// ---------------------------------------------------------------------

const findOrCreateThread = node({
  type: 'n8n-nodes-base.httpRequest',
  version: 4.4,
  config: {
    name: 'Buscar o Crear Hilo de Conversación',
    parameters: {
      method: 'POST',
      url: SUPABASE_RPC_BASE + '/find_or_create_conversation_thread',
      sendBody: true,
      contentType: 'json',
      specifyBody: 'json',
      jsonBody: {
        p_payload: {
          account: { id: expr('{{ $("Buscar o Crear Cuenta").first().json.data }}') },
          conversation: {
            status: 'OPEN',
            conversation_title: expr('{{ $("Limpiar Correo").first().json.subject }}'),
            external_source: 'OUTLOOK',
            external_thread_id: expr('{{ $("Limpiar Correo").first().json.conversationId }}')
          }
        }
      },
      authentication: 'genericCredentialType',
      genericAuthType: 'httpCustomAuth',
      // PostgREST devuelve valores escalares (uuid, boolean) como texto
      // plano, no como JSON válido (p.ej. un uuid sin comillas). Forzar
      // responseFormat:'text' evita que el nodo intente parsear JSON y
      // truene; el texto queda disponible en $json.data (confirmado en
      // ejecución real el 2026-07-21).
      options: { response: { response: { responseFormat: 'text' } } }
    },
    credentials: { httpCustomAuth: newCredential('Supabase Atlas API') }
  },
  output: [{ data: 'e5f6a7b8-0000-0000-0000-000000000000' }]
});

// ---------------------------------------------------------------------
// HTTP: crear la orden de servicio
// ---------------------------------------------------------------------

const createServiceOrder = node({
  type: 'n8n-nodes-base.httpRequest',
  version: 4.4,
  config: {
    name: 'Crear Orden de Servicio',
    parameters: {
      method: 'POST',
      url: SUPABASE_RPC_BASE + '/create_service_order',
      sendBody: true,
      contentType: 'json',
      specifyBody: 'json',
      // NOTA: public.create_service_order solo acepta estos 3 parámetros.
      // p_atlas_context existe en atlas.create_service_order (con DEFAULT
      // '{}'::jsonb) pero NO está expuesto en el wrapper público, así que
      // no se puede enviar el contexto completo de la IA por esta vía.
      // Pendiente de decidir si vale la pena exponer ese parámetro.
      jsonBody: {
        p_account_id: expr('{{ $("Buscar o Crear Cuenta").first().json.data }}'),
        p_priority_code: expr('{{ $("Clasificar y Extraer Reservación").first().json.output.reservation?.priority ?? "NORMAL" }}'),
        p_internal_notes: expr('{{ $("Clasificar y Extraer Reservación").first().json.output.reservation?.customer_notes ?? "" }}')
      },
      authentication: 'genericCredentialType',
      genericAuthType: 'httpCustomAuth',
      // PostgREST devuelve valores escalares (uuid, boolean) como texto
      // plano, no como JSON válido (p.ej. un uuid sin comillas). Forzar
      // responseFormat:'text' evita que el nodo intente parsear JSON y
      // truene; el texto queda disponible en $json.data (confirmado en
      // ejecución real el 2026-07-21).
      options: { response: { response: { responseFormat: 'text' } } }
    },
    credentials: { httpCustomAuth: newCredential('Supabase Atlas API') }
  },
  output: [{ data: 'f6a7b8c9-0000-0000-0000-000000000000' }]
});

// ---------------------------------------------------------------------
// HTTP: vincular la orden de servicio al hilo de conversación
// ---------------------------------------------------------------------

const attachOrderToThread = node({
  type: 'n8n-nodes-base.httpRequest',
  version: 4.4,
  config: {
    name: 'Vincular Orden al Hilo',
    parameters: {
      method: 'POST',
      url: SUPABASE_RPC_BASE + '/attach_service_order_to_thread',
      sendBody: true,
      contentType: 'json',
      specifyBody: 'json',
      jsonBody: {
        p_thread_id: expr('{{ $("Buscar o Crear Hilo de Conversación").first().json.data }}'),
        p_service_order_id: expr('{{ $("Crear Orden de Servicio").first().json.data }}')
      },
      authentication: 'genericCredentialType',
      genericAuthType: 'httpCustomAuth',
      // PostgREST devuelve valores escalares (uuid, boolean) como texto
      // plano, no como JSON válido (p.ej. un uuid sin comillas). Forzar
      // responseFormat:'text' evita que el nodo intente parsear JSON y
      // truene; el texto queda disponible en $json.data (confirmado en
      // ejecución real el 2026-07-21).
      options: { response: { response: { responseFormat: 'text' } } }
    },
    credentials: { httpCustomAuth: newCredential('Supabase Atlas API') }
  },
  output: [{ data: true }]
});

// =====================================================================
// Ronda 10 (2026-07-22): DETECCIÓN DE CONTINUIDAD
// -----------------------------------------------------------------------
// Antes de esta ronda, CADA correo clasificado como reservación creaba una
// orden nueva -- incluso si era solo la respuesta del cliente completando
// un dato que faltaba, lo que generaba una orden duplicada por reservación.
//
// Fase 1 (esta ronda): evitar duplicar la ORDEN completa. Antes de crear
// una orden, se pregunta si el hilo de conversación YA tiene una orden
// abierta (estado "Recibida", es decir aún no confirmada por el equipo).
// Si sí, se reutiliza esa orden en vez de crear una nueva. Si no, todo
// sigue exactamente igual que antes.
//
// Límite conocido y aceptado por ahora: si el cliente repite TODOS los
// detalles del viaje en su respuesta (en vez de solo contestar lo que
// faltaba), podría agregarse un servicio parecido al ya existente DENTRO
// de la misma orden (no una orden duplicada -- solo una fila de servicio
// de más que el equipo consolida a mano). Resolver eso a fondo requeriría
// darle a la IA de extracción visibilidad de lo que el cliente ya
// reservó antes de leer la respuesta nueva -- se deja pendiente hasta
// confirmar con pruebas reales que de verdad hace falta.
// =====================================================================

// ---------------------------------------------------------------------
// HTTP: ¿el hilo de este correo ya tiene una orden abierta?
// ---------------------------------------------------------------------

const checkOpenOrder = node({
  type: 'n8n-nodes-base.httpRequest',
  version: 4.4,
  config: {
    name: 'Buscar Orden Abierta en Hilo',
    parameters: {
      method: 'POST',
      url: SUPABASE_RPC_BASE + '/get_thread_open_order',
      sendBody: true,
      contentType: 'json',
      specifyBody: 'json',
      jsonBody: {
        p_thread_id: expr('{{ $("Buscar o Crear Hilo de Conversación").first().json.data }}')
      },
      authentication: 'genericCredentialType',
      genericAuthType: 'httpCustomAuth',
      // Igual que las demás llamadas RPC: forzar responseFormat:'text'
      // porque get_thread_open_order puede regresar el literal "null"
      // (sin orden abierta), que PostgREST no entrega como JSON parseable
      // de forma consistente si se deja el parseo automático de n8n.
      options: { response: { response: { responseFormat: 'text' } } }
    },
    credentials: { httpCustomAuth: newCredential('Supabase Atlas API') }
  },
  output: [{ data: 'null' }]
});

// ---------------------------------------------------------------------
// IF: ¿el hilo tiene una orden abierta?
// ---------------------------------------------------------------------

// Ronda 12 (2026-07-22): tras prueba real con un hilo NUEVO (sin orden
// abierta), este nodo se equivocó de rama -- truena "Resolver Orden
// Existente" con "Cannot read properties of null (reading 'order_id')".
// Causa: aunque "Buscar Orden Abierta en Hilo" fuerza responseFormat:'text',
// cuando el cuerpo de la respuesta es exactamente el texto "null" (sin
// orden), n8n igual lo convierte al valor real `null` antes de que llegue
// aquí -- así que comparar como STRING contra 'null' nunca detecta ese
// caso de forma confiable. Se cambia a una condición booleana que cubre
// null/undefined/cadena vacía Y el texto literal "null" al mismo tiempo,
// sin depender de adivinar cuál de esas formas usa n8n en cada versión.
const ifThreadHasOpenOrder = ifElse({
  version: 2.3,
  config: {
    name: '¿Hilo Tiene Orden Abierta?',
    parameters: {
      conditions: {
        combinator: 'and',
        options: { caseSensitive: true, leftValue: '', typeValidation: 'strict' },
        conditions: [
          { leftValue: expr('{{ !!$json.data && $json.data !== "null" }}'), operator: { type: 'boolean', operation: 'true' }, rightValue: true }
        ]
      }
    }
  }
});

// ---------------------------------------------------------------------
// CODE: normalizar el id de orden -- caso "ya existía" (rama verdadera)
// ---------------------------------------------------------------------

// Ronda 12 (2026-07-22): se blinda contra las dos formas que puede tomar
// $json.data (string JSON sin parsear, u objeto ya parseado por n8n --
// visto que el comportamiento no fue consistente con lo esperado para el
// caso "null", ver nota arriba en el IF), y se agrega un guard explícito
// -- si por lo que sea este nodo corre sin datos reales de orden, falla
// con un mensaje claro en vez de un TypeError críptico.
const resolveExistingOrder = node({
  type: 'n8n-nodes-base.code',
  version: 2,
  config: {
    name: 'Resolver Orden Existente',
    parameters: {
      mode: 'runOnceForEachItem',
      language: 'javaScript',
      jsCode:
        "let data = $json.data;\n" +
        "if (typeof data === 'string') {\n" +
        "  data = JSON.parse(data);\n" +
        "}\n" +
        "if (!data || !data.order_id) {\n" +
        "  throw new Error('Resolver Orden Existente: no debería ejecutarse sin datos de orden abierta -- revisar la condición de \"¿Hilo Tiene Orden Abierta?\"');\n" +
        "}\n" +
        "return { json: { orderId: data.order_id, isNewOrder: false } };\n"
    }
  },
  output: [{ orderId: 'f6a7b8c9-0000-0000-0000-000000000000', isNewOrder: false }]
});

// ---------------------------------------------------------------------
// CODE: normalizar el id de orden -- caso "se creó una nueva" (rama falsa)
// ---------------------------------------------------------------------
//
// Ambas ramas (Resolver Orden Existente / Resolver Orden Nueva) conectan
// al MISMO nodo "Expandir Servicios" -- patrón de convergencia ("fan-in")
// -- así que todo lo que sigue después ya no necesita saber por cuál
// rama llegó, solo lee $json.orderId del nodo inmediato anterior.

const resolveNewOrder = node({
  type: 'n8n-nodes-base.code',
  version: 2,
  config: {
    name: 'Resolver Orden Nueva',
    parameters: {
      mode: 'runOnceForEachItem',
      language: 'javaScript',
      jsCode:
        "const orderId = $(\"Crear Orden de Servicio\").first().json.data;\n" +
        "return { json: { orderId: orderId, isNewOrder: true } };\n"
    }
  },
  output: [{ orderId: 'f6a7b8c9-0000-0000-0000-000000000000', isNewOrder: true }]
});

// ---------------------------------------------------------------------
// CODE: expandir el arreglo de servicios en un ítem por servicio
// ---------------------------------------------------------------------

const expandServices = node({
  type: 'n8n-nodes-base.code',
  version: 2,
  config: {
    name: 'Expandir Servicios',
    parameters: {
      mode: 'runOnceForAllItems',
      language: 'javaScript',
      jsCode:
        // Ronda 10 (2026-07-22): antes leía el id de orden por nombre desde
        // "Crear Orden de Servicio" -- pero ahora ese nodo NO siempre se
        // ejecuta (se salta cuando el hilo ya tenía una orden abierta), y
        // referenciar por nombre un nodo que no corrió truena en n8n. Como
        // "Expandir Servicios" es el punto de convergencia de ambas ramas
        // (ver "Resolver Orden Existente" / "Resolver Orden Nueva"), basta
        // con leer el ítem que le llegó directamente -- sin importar de
        // cuál rama vino.
        "const orderId = $input.first().json.orderId;\n" +
        // Ronda 11 (2026-07-22): también se propaga isNewOrder -- "Generar
        // Respuesta (Maritza)" lo necesita para saber si es el primer
        // contacto o una continuación (y así no repetir el saludo inicial).
        // Se lee aquí, no directo por nombre, por la misma razón de arriba.
        "const isNewOrder = $input.first().json.isNewOrder;\n" +
        "const services = $(\"Clasificar y Extraer Reservación\").first().json.output.services || [];\n" +
        "\n" +
        "return services.map(function(svc) {\n" +
        "  return { json: { service_order_id: orderId, isNewOrder: isNewOrder, service: svc } };\n" +
        "});\n"
    }
  },
  output: [
    {
      service_order_id: 'f6a7b8c9-0000-0000-0000-000000000000',
      service: {
        direction: 'ARRIVAL',
        service_type: 'TRANSFER',
        origin: 'Aeropuerto Intercontinental de Querétaro (QRO)',
        destination: 'Hotel Real de Minas, San Miguel de Allende',
        scheduled_departure: '2026-08-15T14:30:00-06:00',
        flight_number: 'AM123',
        flight_datetime: '2026-08-15T14:30:00-06:00',
        passenger_count: 4,
        luggage_count: 4,
        client_instructions: ''
      }
    }
  ]
});

// ---------------------------------------------------------------------
// HTTP: agregar cada servicio a la orden (se ejecuta una vez por servicio)
// ---------------------------------------------------------------------

const addService = node({
  type: 'n8n-nodes-base.httpRequest',
  version: 4.4,
  config: {
    name: 'Agregar Servicio',
    parameters: {
      method: 'POST',
      url: SUPABASE_RPC_BASE + '/add_service',
      sendBody: true,
      contentType: 'json',
      specifyBody: 'json',
      jsonBody: {
        p_service_order_id: expr('{{ $json.service_order_id }}'),
        p_service: expr('{{ $json.service }}')
      },
      authentication: 'genericCredentialType',
      genericAuthType: 'httpCustomAuth',
      // PostgREST devuelve valores escalares (uuid, boolean) como texto
      // plano, no como JSON válido (p.ej. un uuid sin comillas). Forzar
      // responseFormat:'text' evita que el nodo intente parsear JSON y
      // truene; el texto queda disponible en $json.data (confirmado en
      // ejecución real el 2026-07-21).
      options: { response: { response: { responseFormat: 'text' } } }
    },
    credentials: { httpCustomAuth: newCredential('Supabase Atlas API') }
  },
  output: [{ data: 'a7b8c9d0-0000-0000-0000-000000000000' }]
});

// ---------------------------------------------------------------------
// HTTP: registrar el mensaje entrante (una sola vez, sin importar cuántos servicios)
// ---------------------------------------------------------------------

const addMessageInbound = node({
  type: 'n8n-nodes-base.httpRequest',
  version: 4.4,
  config: {
    name: 'Registrar Mensaje Entrante',
    executeOnce: true,
    parameters: {
      method: 'POST',
      url: SUPABASE_RPC_BASE + '/add_conversation_message',
      sendBody: true,
      contentType: 'json',
      specifyBody: 'json',
      jsonBody: {
        p_payload: {
          conversation_thread_id: expr('{{ $("Buscar o Crear Hilo de Conversación").first().json.data }}'),
          channel: 'EMAIL',
          message_type: 'EMAIL',
          direction: 'INBOUND',
          sender_person_id: expr('{{ $("Buscar o Crear Persona").first().json.data }}'),
          sender_name: expr('{{ $("Limpiar Correo").first().json.fromName }}'),
          sender_email: expr('{{ $("Limpiar Correo").first().json.fromEmail }}'),
          recipient: 'contact@tripsanmiguel.com',
          subject: expr('{{ $("Limpiar Correo").first().json.subject }}'),
          body_text: expr('{{ $("Limpiar Correo").first().json.cleanBody }}'),
          body_html: expr('{{ $("Limpiar Correo").first().json.rawBodyHtml }}'),
          sent_at: expr('{{ $("Limpiar Correo").first().json.receivedDateTime }}'),
          received_at: expr('{{ $("Limpiar Correo").first().json.receivedDateTime }}'),
          ai_generated: false,
          message_identifier: expr('{{ $("Limpiar Correo").first().json.internetMessageId }}'),
          raw_metadata: expr('{{ $("Clasificar y Extraer Reservación").first().json.output }}')
        }
      },
      authentication: 'genericCredentialType',
      genericAuthType: 'httpCustomAuth',
      // PostgREST devuelve valores escalares (uuid, boolean) como texto
      // plano, no como JSON válido (p.ej. un uuid sin comillas). Forzar
      // responseFormat:'text' evita que el nodo intente parsear JSON y
      // truene; el texto queda disponible en $json.data (confirmado en
      // ejecución real el 2026-07-21).
      options: { response: { response: { responseFormat: 'text' } } }
    },
    credentials: { httpCustomAuth: newCredential('Supabase Atlas API') }
  },
  output: [{ data: 'b8c9d0e1-0000-0000-0000-000000000000' }]
});

// ---------------------------------------------------------------------
// HTTP: alerta interna de nueva reservación recibida
// ---------------------------------------------------------------------

const alertNewReservation = node({
  type: 'n8n-nodes-base.httpRequest',
  version: 4.4,
  config: {
    name: 'Alerta - Nueva Reservación',
    parameters: {
      method: 'POST',
      url: SUPABASE_RPC_BASE + '/create_internal_alert',
      sendBody: true,
      contentType: 'json',
      specifyBody: 'json',
      jsonBody: {
        p_notification_type_code: 'RESERVACION',
        p_subject: expr('Nueva reservación: {{ $("Limpiar Correo").first().json.subject }}'),
        p_message: expr(
          'Cliente: {{ $("Clasificar y Extraer Reservación").first().json.output.client.full_name }}\n' +
          'Servicios solicitados: {{ $("Clasificar y Extraer Reservación").first().json.output.services.length }}\n' +
          'Recibido por correo de: {{ $("Limpiar Correo").first().json.fromEmail }}'
        ),
        // Ronda 10 (2026-07-22): "Crear Orden de Servicio" ya no siempre
        // corre (se salta si el hilo ya tenía una orden abierta) --
        // "Expandir Servicios" sí corre siempre (es el punto de
        // convergencia de ambas ramas), así que es la referencia estable.
        p_service_order_id: expr('{{ $("Expandir Servicios").first().json.service_order_id }}'),
        p_account_id: expr('{{ $("Buscar o Crear Cuenta").first().json.data }}'),
        p_person_id: expr('{{ $("Buscar o Crear Persona").first().json.data }}')
      },
      authentication: 'genericCredentialType',
      genericAuthType: 'httpCustomAuth',
      // PostgREST devuelve valores escalares (uuid, boolean) como texto
      // plano, no como JSON válido (p.ej. un uuid sin comillas). Forzar
      // responseFormat:'text' evita que el nodo intente parsear JSON y
      // truene; el texto queda disponible en $json.data (confirmado en
      // ejecución real el 2026-07-21).
      options: { response: { response: { responseFormat: 'text' } } }
    },
    credentials: { httpCustomAuth: newCredential('Supabase Atlas API') }
  },
  output: [{ data: 'c9d0e1f2-0000-0000-0000-000000000000' }]
});

// ---------------------------------------------------------------------
// IA: generar la respuesta de confirmación (persona "Maritza")
// ---------------------------------------------------------------------

const replyModel = languageModel({
  type: '@n8n/n8n-nodes-langchain.lmChatAnthropic',
  version: 1.5,
  config: {
    name: 'Modelo IA (Respuesta)',
    parameters: {
      model: { __rl: true, mode: 'list', value: 'claude-sonnet-4-6', cachedResultName: 'Claude Sonnet 4.6' },
      options: { maxTokensToSample: 1024 }
    },
    credentials: { anthropicApi: newCredential('Anthropic account') }
  }
});

const replyParser = outputParser({
  type: '@n8n/n8n-nodes-langchain.outputParserStructured',
  version: 1.3,
  config: {
    name: 'Formato de Respuesta',
    parameters: {
      schemaType: 'fromJson',
      // La IA ya NO genera el detalle de cada servicio (fechas, vuelos,
      // pasajeros) -- eso se arma de forma determinística en el nodo
      // "Ensamblar Correo con Plantilla" directamente desde los datos
      // YA EXTRAÍDOS por "Clasificar y Extraer Reservación", para que el
      // itinerario siempre coincida con lo guardado en Supabase y no
      // dependa de que la IA de respuesta reformule bien cada dato.
      // La IA solo aporta el contenido conversacional: saludo, la
      // pregunta de dato faltante (si aplica) y el cierre.
      jsonSchemaExample: JSON.stringify({
        greeting: '¡Hola Juan! Qué gusto saber de ti, gracias por escribirnos.',
        // Ronda 9 (2026-07-22): antes este campo era la pregunta completa
        // (redactada por la IA, juntando todos los datos faltantes). Ahora
        // la lista de qué falta se arma de forma determinística, por
        // servicio, en "Ensamblar Correo con Plantilla" (a partir de
        // missing_fields) -- la IA solo aporta una frase corta que
        // introduce esa lista.
        missing_info_intro: 'Para poder armar tu cotización completa, nos faltan estos datos:',
        closing: 'En cuanto nos confirmes esos datos, te mandamos la cotización formal. Quedamos atentos.'
      })
    }
  }
});

const generateReply = node({
  type: '@n8n/n8n-nodes-langchain.agent',
  version: 3.1,
  config: {
    name: 'Generar Respuesta (Maritza)',
    parameters: {
      promptType: 'define',
      text: expr(
        'Cliente: {{ $("Clasificar y Extraer Reservación").first().json.output.client.full_name }}\n' +
        'Idioma del cliente detectado (es/en): {{ $("Clasificar y Extraer Reservación").first().json.output.client_language ?? "es" }}\n' +
        'Asunto original: {{ $("Limpiar Correo").first().json.subject }}\n' +
        // Ronda 11 (2026-07-22): se agrega si es primer contacto o
        // continuación -- tras prueba real, el saludo repetía "gracias por
        // escribirnos y confiar en nosotros" de forma idéntica en cada
        // respuesta del mismo hilo, sonando repetitivo/robótico.
        '¿Primer contacto o continuación?: {{ $("Expandir Servicios").first().json.isNewOrder ? "Primer contacto (aún no le habíamos respondido en este hilo)" : "Continuación (ya le habíamos respondido antes en este mismo hilo)" }}\n' +
        'Servicios capturados (JSON): {{ JSON.stringify($("Clasificar y Extraer Reservación").first().json.output.services) }}\n' +
        'Notas del cliente: {{ $("Clasificar y Extraer Reservación").first().json.output.reservation?.customer_notes ?? "" }}'
      ),
      hasOutputParser: true,
      options: {
        // La IA solo redacta el contenido conversacional (saludo, la
        // pregunta de dato faltante si aplica, y el cierre). El detalle
        // de cada servicio (fechas, vuelos, pasajeros) NO lo genera la
        // IA -- se arma aparte, en "Ensamblar Correo con Plantilla",
        // directamente desde los datos ya extraídos y validados, para
        // que el itinerario nunca se desvíe de lo guardado en Supabase.
        // Instrucción explícita contra diminutivos ("preguntita", etc.)
        // tras feedback directo del usuario de que sonaban poco
        // profesionales, aunque el tono deba seguir siendo relajado.
        // Ronda 4 (2026-07-22): se agregó una restricción adicional contra
        // comentarios casuales de relleno tipo broma (p.ej. "se nota que
        // vienes bien preparado"), que el usuario encontró demasiado
        // informales pese a no ser diminutivos.
        // Ronda 5 (2026-07-22): el usuario notó que, tras esa restricción,
        // el saludo/cierre podían sentirse impersonales -- se agrega guía
        // POSITIVA concreta (no solo qué evitar) para que la calidez se
        // note de verdad, y se corrige el nombre a "Ing. Maritza Chávez".
        // Ronda 6 (2026-07-22), tras prueba real: la pregunta de dato
        // faltante se limitaba a UN solo dato aunque faltara más de uno
        // (ej. número de vuelo Y equipaje) -- ahora se le pide juntar
        // TODOS los datos faltantes en una sola pregunta.
        // Ronda 7 (2026-07-22), tras prueba real con un correo en inglés:
        // la IA respondió en español sin importar el idioma del cliente.
        // Ahora escribe en el idioma detectado por "Clasificar y Extraer
        // Reservación" (client_language) -- el resto de la plantilla
        // (etiquetas, botones) también se traduce, pero eso pasa en
        // "Ensamblar Correo con Plantilla", no aquí.
        // Ronda 8 (2026-07-22): la Ronda 6 pedía "juntar todos los datos
        // faltantes", pero la IA seguía viendo solo UNO porque intentaba
        // inferir qué faltaba a partir de los números crudos (0 podía
        // significar "no mencionado" o "el cliente confirmó cero", sin
        // forma de distinguirlos). Ahora "Clasificar y Extraer
        // Reservación" ya decide explícitamente qué falta por servicio
        // (missing_fields), así que aquí solo hay que leerlo y redactar
        // la pregunta -- ya no hay que adivinar.
        // Ronda 9 (2026-07-22): el usuario pidió que la lista de datos
        // faltantes se vea más fácil de leer, agrupada por servicio (en
        // vez de un solo párrafo con todo junto). En lugar de pedirle a
        // la IA que redacte una lista bien formateada -- frágil, depende
        // de que la IA la estructure bien cada vez -- la lista ahora se
        // arma de forma determinística en "Ensamblar Correo con
        // Plantilla" directamente desde missing_fields (mismo patrón que
        // el itinerario). La IA ya NO redacta la pregunta ni la lista,
        // solo una frase corta que la introduce.
        systemMessage:
          'Eres Ing. Maritza Chávez, Coordinadora de Reservaciones de Transportes y Tours San Miguel Mágico, ' +
          'una empresa familiar de transporte turístico. Tu trabajo es redactar SOLO el contenido ' +
          'conversacional del mensaje -- el detalle de cada servicio (fechas, horarios, vuelos, pasajeros) se ' +
          'arma aparte a partir de los datos ya capturados, tú NO lo repites ni lo resumes. Escribe SIEMPRE en ' +
          'el idioma indicado en "Idioma del cliente detectado": si es "en", escribe todo en inglés natural ' +
          '-- si es "es" o cualquier otro valor, escribe en español (idioma por default del negocio). Usa ' +
          'un tono cálido, natural y cercano, ligeramente relajado -- como si tú misma le escribieras a ' +
          'alguien que te cae bien -- pero siempre profesional: NUNCA uses diminutivos (nada de "preguntita", ' +
          '"mensajito", "ratito", etc.), evita sonar acartonada y evita frases de formulario. Evita también ' +
          'comentarios casuales de relleno que suenen a broma o a frase hecha sobre el cliente o su viaje ' +
          '(por ejemplo, NUNCA digas algo como "se nota que vienes bien preparado" ni variantes similares) ' +
          '-- la calidez debe sentirse en el tono general del mensaje, no en ese tipo de comentario suelto. ' +
          'Para que el saludo y el cierre no se sientan genéricos ni impersonales: agradece con sinceridad el ' +
          'interés del cliente en viajar con nosotros, muestra ganas reales de ayudarle a que todo salga bien ' +
          'en su viaje, y si el correo menciona algo distintivo (el destino, una fecha especial, el motivo del ' +
          'viaje), puedes retomarlo brevemente de forma natural -- sin exagerar ni convertirlo en broma. NO ' +
          'generes HTML, NO uses negritas, NO uses emojis, y NO incluyas firma ni despedida con tu nombre/' +
          'puesto/empresa -- el sistema agrega la firma automáticamente.\n\n' +
          'Devuelve:\n' +
          // Ronda 11 (2026-07-22): distinguir primer contacto vs. continuación
          // (ver "¿Primer contacto o continuación?" arriba) para que el
          // saludo no repita la misma introducción en cada respuesta del
          // mismo hilo.
          '- greeting: saludo cálido y genuino (una o dos frases). Si es "Primer contacto", agradece la ' +
          'solicitud y el interés del cliente en viajar con nosotros, como siempre. Si es "Continuación", NO ' +
          'repitas ese agradecimiento inicial (ya se dijo en la primera respuesta de este hilo) -- en su ' +
          'lugar, reconoce con calidez y de forma breve la información nueva que el cliente acaba de ' +
          'compartir, como si retomaras una conversación que ya iba en marcha.\n' +
          '- missing_info_intro: el sistema ya arma automáticamente, por servicio, la lista exacta de qué ' +
          'falta (usando missing_fields de cada servicio en "Servicios capturados") -- TÚ NO redactes esa ' +
          'lista ni menciones los datos específicos o el nombre de ningún servicio. Tu única tarea aquí es ' +
          'escribir UNA frase corta y cálida que introduzca esa lista (ej. "Para poder armar tu cotización ' +
          'completa, nos faltan estos datos:"), sin diminutivos. Si NINGÚN servicio en "Servicios capturados" ' +
          'tiene missing_fields no vacío, deja este campo como cadena vacía "".\n' +
          '- closing: cierre cálido y personal antes de la firma (una o dos frases, sin incluir la firma ' +
          'misma).\n\n' +
          'Responde ÚNICAMENTE con el JSON solicitado, sin texto adicional.'
      }
    },
    subnodes: { model: replyModel, outputParser: replyParser }
  },
  output: [
    {
      output: {
        greeting: '¡Hola Juan! Qué gusto saber de ti, gracias por escribirnos.',
        missing_info_question: '¿Nos podrías confirmar cuántos pasajeros serán para el traslado del 15 de agosto?',
        closing: 'En cuanto nos confirmes ese dato, te mandamos la cotización formal. Quedamos atentos.'
      }
    }
  ]
});

// ---------------------------------------------------------------------
// CÓDIGO: ensamblar el HTML final de marca a partir del contenido de la IA
// ---------------------------------------------------------------------
//
// Separación de responsabilidades: la IA (generateReply) entrega SOLO
// contenido estructurado; este nodo arma el HTML de marca (azul, tarjetas
// por servicio, firma con avatar circular y datos de contacto) de forma
// determinística. Esto da consistencia visual en cada correo sin depender
// de que la IA reproduzca HTML pixel-perfect cada vez -- más simple,
// robusto y mantenible que hacer prompt-engineering del diseño.
const assembleEmail = node({
  type: 'n8n-nodes-base.code',
  version: 2,
  config: {
    name: 'Ensamblar Correo con Plantilla',
    parameters: {
      mode: 'runOnceForEachItem',
      // Rediseño 2026-07-22 (tercera pasada) tras feedback del usuario:
      // paleta reducida a 5 colores propios (#1C558C azul, #22384D texto,
      // #8C621C acento cálido para la pregunta, #372D1D para el toque
      // clásico de la cabecera, #B3DAFF fondo suave) en vez de la mezcla
      // anterior; íconos VECTORIALES reales (PNG alojados en Supabase
      // Storage, bucket público "email-icons") en vez de emojis/entidades
      // Unicode -- auto, maleta, persona, calendario, signo de pregunta
      // en círculo, sobre/teléfono/globo/estrella/enviar -- porque tanto
      // el SVG en línea como las imágenes base64 NO se muestran en el
      // Outlook de escritorio clásico (limitación conocida del cliente,
      // confirmada con el usuario antes de implementar esta vía).
      // Tipografía Roboto (con fallback a Arial/Helvetica) en todo el
      // cuerpo; la cabecera y el pie usan una serif clásica (Georgia)
      // para un toque cálido, tal como se pidió explícitamente.
      // Resumen gráfico con íconos por dato (pasajeros/equipaje/
      // servicios/tipo) antes de una frase fija "A continuación te envío
      // los datos de tu reserva:". La pregunta de dato faltante ya NO va
      // en una caja con borde -- solo el ícono de círculo con "?" y texto
      // más grande, más un botón de llamada a la acción que abre un
      // borrador de correo ya dirigido y con asunto prellenado (mailto:),
      // para que el cliente pueda responder de inmediato sabiendo
      // exactamente qué va a pasar al hacer clic.
      //
      // Ronda 4 (2026-07-22), tras ver el resultado en vivo:
      // - Se quitó la "tarjeta" blanca con sombra sobre fondo gris (estilo
      //   newsletter) -- se veía bien en celular pero rara en escritorio.
      //   Ahora el correo va sobre el fondo normal, solo centrado y
      //   limitado a 640px de ancho de lectura, como un correo tradicional.
      //   Se prefirió este enfoque simple y no-responsivo (en vez de media
      //   queries) porque Outlook de escritorio las ignora, igual que
      //   ignora el SVG/HTML embebido.
      // - Se quitó el recuadro/fondo de color detrás de cada servicio en
      //   la línea del tiempo -- ahora el contenido va directo sobre el
      //   fondo normal (el círculo numerado, la fecha y el conector SÍ se
      //   conservan, no fueron objeto de la crítica).
      // - Se corrigió el avatar circular "M" de la firma, que se veía
      //   desfasado del círculo en celular: se cambió el centrado de
      //   <div>+line-height (poco confiable en clientes móviles/webview)
      //   por la técnica "bulletproof" de tabla con align/valign HTML.
      // - Los íconos se regeneraron en un estilo de línea/contorno más
      //   sutil y minimalista (mismos nombres de archivo en el mismo
      //   bucket, así que no cambian las URLs).
      // - Se agregó, muy discreta al pie, una referencia corta de la
      //   orden (primeros 8 caracteres del UUID) solo para dar
      //   seguimiento interno -- el cliente no necesita usarla.
      //
      // Ronda 6/7 (2026-07-22), tras primera prueba con un correo real
      // (formulario del sitio web, escrito en inglés):
      // - Todo el texto FIJO de la plantilla (etiquetas, botones, pie de
      //   página, encabezado) ahora vive en un diccionario T{es,en} y se
      //   elige según client_language (detectado por "Clasificar y
      //   Extraer Reservación" a partir del propio correo del cliente).
      //   Antes solo el contenido de la IA podía cambiar de idioma, lo
      //   que producía correos mezclados. El texto libre extraído del
      //   correo (notas, nombres de lugares) NO se traduce -- traducirlo
      //   arriesgaría alterar los hechos que el cliente escribió.
      // - Cada tipo de servicio ahora tiene su propio ícono (antes
      //   siempre era el auto sin importar el tipo): auto para
      //   TRANSFER/ROUND_TRIP, reloj para HOURLY, brújula para TOUR.
      jsCode:
        "// ============ ICONS (alojados en Supabase Storage, bucket público \"email-icons\") ============\n" +
        "const ICON_BASE = 'https://kdtagfclulhupxkuojhx.supabase.co/storage/v1/object/public/email-icons';\n" +
        "const ICONS = {\n" +
        "  car: ICON_BASE + '/car.png',\n" +
        "  suitcase: ICON_BASE + '/suitcase.png',\n" +
        "  person: ICON_BASE + '/person.png',\n" +
        "  calendar: ICON_BASE + '/calendar.png',\n" +
        "  question: ICON_BASE + '/question.png',\n" +
        "  envelope: ICON_BASE + '/envelope.png',\n" +
        "  phone: ICON_BASE + '/phone.png',\n" +
        "  globe: ICON_BASE + '/globe.png',\n" +
        "  star: ICON_BASE + '/star.png',\n" +
        "  send: ICON_BASE + '/send.png',\n" +
        "  clock: ICON_BASE + '/clock.png',\n" +
        "  compass: ICON_BASE + '/compass.png'\n" +
        "};\n" +
        "\n" +
        "const FONT = \"'Roboto',Arial,Helvetica,sans-serif\";\n" +
        "const SERIF = \"Georgia,'Times New Roman',serif\";\n" +
        "const NAVY = '#22384D';\n" +
        "const BLUE = '#1C558C';\n" +
        "const BROWN = '#8C621C';\n" +
        "const DEEPBROWN = '#372D1D';\n" +
        "const LIGHTBLUE = '#B3DAFF';\n" +
        "\n" +
        "// ============ TEXTOS / TRADUCCIONES ============\n" +
        "// Todo el texto fijo de la plantilla vive aquí, en dos idiomas. El campo\n" +
        "// client_language (detectado por \"Clasificar y Extraer Reservación\" a\n" +
        "// partir del propio correo del cliente) decide cuál set se usa -- así\n" +
        "// el correo completo sale en un solo idioma consistente, no solo el\n" +
        "// texto que redacta la IA.\n" +
        "const T = {\n" +
        "  es: {\n" +
        "    introLine: 'A continuación te envío los datos de tu reserva:',\n" +
        "    fieldLabels: { time: 'Hora', route: 'Trayecto', flight: 'Vuelo', passengers: 'Pasajeros', note: 'Nota' },\n" +
        "    serviceTypeLabels: { TRANSFER: 'Traslado', ROUND_TRIP: 'Viaje redondo', HOURLY: 'Servicio por horas', TOUR: 'Recorrido turístico' },\n" +
        "    arrivalSuffix: ' de llegada',\n" +
        "    departureSuffix: ' de salida',\n" +
        "    passengerWord: function(n) { return n === 1 ? ' pasajero' : ' pasajeros'; },\n" +
        "    luggageWord: function(n) { return n === 1 ? ' maleta' : ' maletas'; },\n" +
        "    summaryLabels: { passengers: 'Pasajeros', luggage: 'Equipaje', servicesSingular: 'Servicio', servicesPlural: 'Servicios', type: 'Tipo' },\n" +
        "    replyButton: 'Responder este correo',\n" +
        "    replyHelper: 'Al hacer clic se abre un borrador ya listo para que nos respondas.',\n" +
        "    mailBodyStarter: 'Hola, sobre mi reservación:\\n\\n',\n" +
        "    footer: 'Gracias por elegirnos para acompañarte en tu próximo viaje.',\n" +
        "    headerTagline: 'Llega relajado. Parte inspirado.',\n" +
        "    tripadvisorLabel: 'Califícanos en TripAdvisor',\n" +
        "    jobTitle: 'Coordinadora de Reservaciones',\n" +
        "    vehicleAlt: 'Vehículo',\n" +
        "    questionAlt: 'Pregunta',\n" +
        "    orderRefLabel: 'Ref. de reserva:',\n" +
        "    missingFieldLabels: { TIME: 'Hora exacta', FLIGHT_NUMBER: 'Número de vuelo', PASSENGER_COUNT: 'Número de pasajeros', LUGGAGE_COUNT: 'Equipaje (cuántas maletas)' },\n" +
        "    missingInfoFallbackIntro: 'Para completar tu reservación, nos faltan estos datos:',\n" +
        "    monthsAbbr: ['ENE','FEB','MAR','ABR','MAY','JUN','JUL','AGO','SEP','OCT','NOV','DIC']\n" +
        "  },\n" +
        "  en: {\n" +
        "    introLine: 'Here are your reservation details:',\n" +
        "    fieldLabels: { time: 'Time', route: 'Route', flight: 'Flight', passengers: 'Passengers', note: 'Note' },\n" +
        "    serviceTypeLabels: { TRANSFER: 'Transfer', ROUND_TRIP: 'Round trip', HOURLY: 'Hourly service', TOUR: 'Tour' },\n" +
        "    arrivalSuffix: ' (arrival)',\n" +
        "    departureSuffix: ' (departure)',\n" +
        "    passengerWord: function(n) { return n === 1 ? ' passenger' : ' passengers'; },\n" +
        "    luggageWord: function(n) { return n === 1 ? ' bag' : ' bags'; },\n" +
        "    summaryLabels: { passengers: 'Passengers', luggage: 'Luggage', servicesSingular: 'Service', servicesPlural: 'Services', type: 'Type' },\n" +
        "    replyButton: 'Reply to this email',\n" +
        "    replyHelper: 'Clicking this opens a draft ready for you to send us.',\n" +
        "    mailBodyStarter: 'Hi, regarding my reservation:\\n\\n',\n" +
        "    footer: 'Thank you for choosing us for your next trip.',\n" +
        "    headerTagline: 'Arrive relaxed. Leave inspired.',\n" +
        "    tripadvisorLabel: 'Rate us on TripAdvisor',\n" +
        "    jobTitle: 'Reservations Coordinator',\n" +
        "    vehicleAlt: 'Vehicle',\n" +
        "    questionAlt: 'Question',\n" +
        "    orderRefLabel: 'Booking ref.:',\n" +
        "    missingFieldLabels: { TIME: 'Exact time', FLIGHT_NUMBER: 'Flight number', PASSENGER_COUNT: 'Number of passengers', LUGGAGE_COUNT: 'Luggage (how many bags)' },\n" +
        "    missingInfoFallbackIntro: 'To finish your booking, we still need these details:',\n" +
        "    monthsAbbr: ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC']\n" +
        "  }\n" +
        "};\n" +
        "\n" +
        "const data = $json.output || {};\n" +
        "const greeting = data.greeting || '';\n" +
        "// Ronda 9 (2026-07-22): la IA ya NO redacta la lista de qué falta -- solo\n" +
        "// una frase corta de introducción. La lista en sí (por servicio) se arma\n" +
        "// de forma determinística abajo, a partir de missing_fields, igual que ya\n" +
        "// se hace con el itinerario -- así el correo nunca puede \"olvidar\" un\n" +
        "// dato faltante ni mezclarlos todos en un párrafo difícil de leer.\n" +
        "const missingIntro = data.missing_info_intro || '';\n" +
        "const closing = data.closing || '';\n" +
        "\n" +
        "const extraction = $(\"Clasificar y Extraer Reservación\").first().json.output || {};\n" +
        "const services = extraction.services || [];\n" +
        "const originalSubject = $(\"Limpiar Correo\").first().json.subject || '';\n" +
        "\n" +
        "// Idioma detectado del cliente -- solo se soportan \"es\"/\"en\" por ahora\n" +
        "// (ver nota T arriba). Cualquier otro valor cae a español, el idioma\n" +
        "// por default del negocio.\n" +
        "const lang = extraction.client_language === 'en' ? 'en' : 'es';\n" +
        "const L = T[lang];\n" +
        "\n" +
        "// Referencia corta de la orden, solo para seguimiento interno -- el\n" +
        "// cliente no necesita usarla, se muestra muy discreta al final del correo.\n" +
        "// Ronda 10 (2026-07-22): se lee desde \"Expandir Servicios\" en vez de\n" +
        "// \"Crear Orden de Servicio\" -- ese nodo ya no siempre corre.\n" +
        "const rawOrderId = ($(\"Expandir Servicios\").first().json.service_order_id || '').toString();\n" +
        "const orderRef = rawOrderId ? rawOrderId.replace(/-/g, '').slice(0, 8).toUpperCase() : '';\n" +
        "\n" +
        "function escapeHtml(str) {\n" +
        "  return String(str || '')\n" +
        "    .replace(/&/g, '&amp;')\n" +
        "    .replace(/</g, '&lt;')\n" +
        "    .replace(/>/g, '&gt;');\n" +
        "}\n" +
        "\n" +
        "function formatDate(iso) {\n" +
        "  const m = /^(\\d{4})-(\\d{2})-(\\d{2})/.exec(iso || '');\n" +
        "  if (!m) return null;\n" +
        "  const day = parseInt(m[3], 10);\n" +
        "  const month = L.monthsAbbr[parseInt(m[2], 10) - 1] || '';\n" +
        "  return { day: String(day), month: month };\n" +
        "}\n" +
        "\n" +
        "function formatTime(iso) {\n" +
        "  const m = /T(\\d{2}):(\\d{2})/.exec(iso || '');\n" +
        "  if (!m) return '';\n" +
        "  let hour = parseInt(m[1], 10);\n" +
        "  const minute = m[2];\n" +
        "  const ampm = hour >= 12 ? 'p.m.' : 'a.m.';\n" +
        "  hour = hour % 12;\n" +
        "  if (hour === 0) hour = 12;\n" +
        "  return hour + ':' + minute + ' ' + ampm;\n" +
        "}\n" +
        "\n" +
        "// Ícono por tipo de servicio -- antes siempre era el auto (ICONS.car)\n" +
        "// sin importar el tipo; ahora cada tipo tiene su propio ícono para que\n" +
        "// el resumen/itinerario se distinga de un vistazo.\n" +
        "const SERVICE_TYPE_ICONS = {\n" +
        "  TRANSFER: ICONS.car,\n" +
        "  ROUND_TRIP: ICONS.car,\n" +
        "  HOURLY: ICONS.clock,\n" +
        "  TOUR: ICONS.compass\n" +
        "};\n" +
        "\n" +
        "function iconImg(iconUrl, alt, size) {\n" +
        "  size = size || 16;\n" +
        "  return '<img src=\"' + iconUrl + '\" width=\"' + size + '\" height=\"' + size + '\" alt=\"' + alt + '\" style=\"display:inline-block;vertical-align:middle;border:0;margin-right:6px;\" />';\n" +
        "}\n" +
        "\n" +
        "function serviceTitle(svc) {\n" +
        "  const label = L.serviceTypeLabels[svc.service_type] || 'Servicio';\n" +
        "  let suffix = '';\n" +
        "  if (svc.service_type === 'TRANSFER' || svc.service_type === 'ROUND_TRIP') {\n" +
        "    if (svc.direction === 'ARRIVAL') suffix = L.arrivalSuffix;\n" +
        "    else if (svc.direction === 'DEPARTURE') suffix = L.departureSuffix;\n" +
        "  }\n" +
        "  const icon = SERVICE_TYPE_ICONS[svc.service_type] || ICONS.car;\n" +
        "  return iconImg(icon, L.vehicleAlt, 15) + label + suffix;\n" +
        "}\n" +
        "\n" +
        "function serviceFieldRows(svc) {\n" +
        "  const rows = [];\n" +
        "  const time = formatTime(svc.scheduled_departure);\n" +
        "  if (time) rows.push({ label: L.fieldLabels.time, valueHtml: escapeHtml(time) });\n" +
        "  if (svc.origin || svc.destination) {\n" +
        "    rows.push({ label: L.fieldLabels.route, valueHtml: escapeHtml(svc.origin || '—') + ' &rarr; ' + escapeHtml(svc.destination || '—') });\n" +
        "  }\n" +
        "  if (svc.flight_number) rows.push({ label: L.fieldLabels.flight, valueHtml: escapeHtml(svc.flight_number) });\n" +
        "  // Un valor en 0 puede significar \"el cliente no lo mencionó\" o \"el\n" +
        "  // cliente confirmó que es cero\" (ej. \"no llevamos equipaje\") -- ambos\n" +
        "  // casos ya no se distinguen por el número, sino por missing_fields\n" +
        "  // (ver \"Clasificar y Extraer Reservación\"). Solo mostramos el dato si\n" +
        "  // NO está marcado como faltante, para no ocultar un \"0\" ya confirmado\n" +
        "  // ni mostrar un \"0\" que en realidad nunca se preguntó.\n" +
        "  const missing = svc.missing_fields || [];\n" +
        "  const paxParts = [];\n" +
        "  if (svc.passenger_count || missing.indexOf('PASSENGER_COUNT') === -1) {\n" +
        "    paxParts.push(svc.passenger_count + L.passengerWord(svc.passenger_count));\n" +
        "  }\n" +
        "  if (svc.luggage_count || missing.indexOf('LUGGAGE_COUNT') === -1) {\n" +
        "    paxParts.push(svc.luggage_count + L.luggageWord(svc.luggage_count));\n" +
        "  }\n" +
        "  if (paxParts.length) rows.push({ label: L.fieldLabels.passengers, valueHtml: escapeHtml(paxParts.join(' · ')) });\n" +
        "  if (svc.client_instructions) rows.push({ label: L.fieldLabels.note, valueHtml: escapeHtml(svc.client_instructions) });\n" +
        "  return rows;\n" +
        "}\n" +
        "\n" +
        "function fieldRowsHtml(rows) {\n" +
        "  return '<table role=\"presentation\" style=\"width:100%;border-collapse:collapse;margin-top:8px;\">' +\n" +
        "    rows.map(function(r) {\n" +
        "      return '<tr>' +\n" +
        "        '<td style=\"padding:2px 10px 2px 0;vertical-align:top;width:96px;font-family:' + FONT + ';font-size:11px;color:#5C7488;text-transform:uppercase;letter-spacing:0.4px;\">' + escapeHtml(r.label) + '</td>' +\n" +
        "        '<td style=\"padding:2px 0;vertical-align:top;font-family:' + FONT + ';font-size:13px;color:' + NAVY + ';\">' + r.valueHtml + '</td>' +\n" +
        "      '</tr>';\n" +
        "    }).join('') +\n" +
        "  '</table>';\n" +
        "}\n" +
        "\n" +
        "function serviceCardHtml(svc) {\n" +
        "  return '<table role=\"presentation\" style=\"width:100%;border-collapse:collapse;\">' +\n" +
        "    '<tr><td style=\"padding:0;\">' +\n" +
        "    '<p style=\"margin:0;font-weight:700;color:' + BLUE + ';font-family:' + FONT + ';font-size:14px;\">' + serviceTitle(svc) + '</p>' +\n" +
        "    fieldRowsHtml(serviceFieldRows(svc)) +\n" +
        "    '</td></tr></table>';\n" +
        "}\n" +
        "\n" +
        "function markerHtml(svc, index) {\n" +
        "  const d = formatDate(svc.scheduled_departure);\n" +
        "  const dayHtml = d\n" +
        "    ? '<p style=\"margin:6px 0 0 0;font-size:20px;font-weight:700;color:' + BLUE + ';font-family:' + FONT + ';line-height:1;\">' + escapeHtml(d.day) + '</p>' +\n" +
        "      '<p style=\"margin:0;font-size:10px;font-weight:700;letter-spacing:0.5px;color:' + NAVY + ';text-transform:uppercase;font-family:' + FONT + ';\">' + escapeHtml(d.month) + '</p>'\n" +
        "    : '';\n" +
        "  return '<table role=\"presentation\" style=\"border-collapse:collapse;margin:0 auto;\"><tr><td bgcolor=\"' + BLUE + '\" style=\"width:24px;height:24px;border-radius:50%;background:' + BLUE + ';color:#ffffff;font-size:11px;font-weight:700;text-align:center;line-height:24px;font-family:' + FONT + ';\">' + (index + 1) + '</td></tr></table>' + dayHtml;\n" +
        "}\n" +
        "\n" +
        "function timelineHtml(list) {\n" +
        "  if (!list.length) return '';\n" +
        "  let out = '<table role=\"presentation\" style=\"width:100%;border-collapse:collapse;\">';\n" +
        "  list.forEach(function(svc, i) {\n" +
        "    const isLast = i === list.length - 1;\n" +
        "    out += '<tr>' +\n" +
        "      '<td style=\"width:64px;vertical-align:top;text-align:center;padding-top:2px;\">' + markerHtml(svc, i) + '</td>' +\n" +
        "      '<td style=\"padding:0 0 ' + (isLast ? '4px' : '20px') + ' 14px;\">' + serviceCardHtml(svc) + '</td>' +\n" +
        "    '</tr>';\n" +
        "    if (!isLast) {\n" +
        "      out += '<tr>' +\n" +
        "        '<td style=\"width:64px;text-align:center;\">' +\n" +
        "          '<table role=\"presentation\" style=\"border-collapse:collapse;margin:0 auto;\"><tr><td bgcolor=\"' + LIGHTBLUE + '\" style=\"width:2px;height:16px;background:' + LIGHTBLUE + ';font-size:1px;line-height:1px;\">&nbsp;</td></tr></table>' +\n" +
        "        '</td>' +\n" +
        "        '<td></td>' +\n" +
        "      '</tr>';\n" +
        "    }\n" +
        "  });\n" +
        "  out += '</table>';\n" +
        "  return out;\n" +
        "}\n" +
        "\n" +
        "function buildSummary(list) {\n" +
        "  let maxPax = 0, maxLuggage = 0;\n" +
        "  const types = [];\n" +
        "  list.forEach(function(svc) {\n" +
        "    if (svc.passenger_count && svc.passenger_count > maxPax) maxPax = svc.passenger_count;\n" +
        "    if (svc.luggage_count && svc.luggage_count > maxLuggage) maxLuggage = svc.luggage_count;\n" +
        "    const label = L.serviceTypeLabels[svc.service_type] || svc.service_type;\n" +
        "    if (label && types.indexOf(label) === -1) types.push(label);\n" +
        "  });\n" +
        "  return { passengers: maxPax || null, luggage: maxLuggage || null, total: list.length, typeLabel: types.join(' · ') || '—' };\n" +
        "}\n" +
        "\n" +
        "function summaryTileHtml(iconUrl, alt, value, label, fontSize) {\n" +
        "  return '<td style=\"width:25%;padding:4px;\">' +\n" +
        "    '<table role=\"presentation\" style=\"width:100%;border-collapse:collapse;background:' + LIGHTBLUE + ';border-radius:8px;\">' +\n" +
        "    '<tr><td style=\"padding:14px 6px;text-align:center;\">' +\n" +
        "    '<img src=\"' + iconUrl + '\" width=\"22\" height=\"22\" alt=\"' + alt + '\" style=\"display:block;margin:0 auto 6px auto;border:0;\" />' +\n" +
        "    '<p style=\"margin:0;font-size:' + (fontSize || 20) + 'px;font-weight:700;color:' + BLUE + ';font-family:' + FONT + ';line-height:1.15;\">' + value + '</p>' +\n" +
        "    '<p style=\"margin:3px 0 0 0;font-size:9px;font-weight:700;letter-spacing:0.5px;color:' + NAVY + ';text-transform:uppercase;font-family:' + FONT + ';\">' + label + '</p>' +\n" +
        "    '</td></tr></table>' +\n" +
        "  '</td>';\n" +
        "}\n" +
        "\n" +
        "function summaryHtml(list) {\n" +
        "  if (!list.length) return '';\n" +
        "  const s = buildSummary(list);\n" +
        "  return '<table role=\"presentation\" style=\"width:100%;border-collapse:collapse;margin:14px 0 4px 0;\"><tr>' +\n" +
        "    summaryTileHtml(ICONS.person, L.summaryLabels.passengers, s.passengers != null ? s.passengers : '—', L.summaryLabels.passengers) +\n" +
        "    summaryTileHtml(ICONS.suitcase, L.summaryLabels.luggage, s.luggage != null ? s.luggage : '—', L.summaryLabels.luggage) +\n" +
        "    summaryTileHtml(ICONS.calendar, L.summaryLabels.servicesPlural, String(s.total), s.total === 1 ? L.summaryLabels.servicesSingular : L.summaryLabels.servicesPlural) +\n" +
        "    summaryTileHtml(ICONS.car, L.summaryLabels.type, escapeHtml(s.typeLabel), L.summaryLabels.type, 13) +\n" +
        "  '</tr></table>';\n" +
        "}\n" +
        "\n" +
        "// Ronda 9 (2026-07-22): antes esta sección era UN párrafo de texto libre\n" +
        "// redactado por la IA, juntando todos los datos faltantes de todos los\n" +
        "// servicios -- difícil de leer cuando había varios. Ahora la lista se\n" +
        "// arma aquí, agrupada por servicio (igual que el itinerario), y la IA\n" +
        "// solo aporta una frase corta de introducción. La condición para mostrar\n" +
        "// esta sección ya no depende de si la IA escribió texto, sino de los\n" +
        "// datos reales (missing_fields) -- más robusto, no depende de que la IA\n" +
        "// \"recuerde\" mencionar la sección.\n" +
        // Ronda 11 (2026-07-22): dos cambios tras prueba real --
        // (1) se filtran defensivamente los códigos que no estén en
        // missingFieldLabels: si la IA algún día vuelve a inventar un código
        // fuera del catálogo (pasó con "PHONE"), aquí simplemente se ignora
        // en vez de enseñarle al cliente el texto crudo del código.
        // (2) se agrega followup_question como un ítem más de la misma
        // lista -- la pregunta de aclaración puntual que la IA de extracción
        // puede generar para circunstancias especiales (ver systemMessage de
        // "Clasificar y Extraer Reservación").
        "function knownMissingCodes(svc) {\n" +
        "  return (svc.missing_fields || []).filter(function(code) { return !!L.missingFieldLabels[code]; });\n" +
        "}\n" +
        "\n" +
        "function missingFieldsListHtml(svc) {\n" +
        "  const items = knownMissingCodes(svc).map(function(code) {\n" +
        "    return '<li style=\"margin:0 0 2px 0;\">' + escapeHtml(L.missingFieldLabels[code]) + '</li>';\n" +
        "  });\n" +
        "  if (svc.followup_question) {\n" +
        "    items.push('<li style=\"margin:0 0 2px 0;\">' + escapeHtml(svc.followup_question) + '</li>');\n" +
        "  }\n" +
        "  return '<ul style=\"margin:2px 0 12px 18px;padding:0;font-family:' + FONT + ';font-size:13px;color:' + NAVY + ';line-height:1.5;\">' +\n" +
        "    items.join('') +\n" +
        "    '</ul>';\n" +
        "}\n" +
        "\n" +
        "function pendingHtml(intro, list, subject) {\n" +
        "  const withMissing = list.filter(function(svc) { return knownMissingCodes(svc).length > 0 || !!svc.followup_question; });\n" +
        "  if (!withMissing.length) return '';\n" +
        "  const introText = intro || L.missingInfoFallbackIntro;\n" +
        "  const mailBody = encodeURIComponent(L.mailBodyStarter);\n" +
        "  const mailSubj = encodeURIComponent('RE: ' + subject);\n" +
        "  const mailHref = 'mailto:contact@tripsanmiguel.com?subject=' + mailSubj + '&body=' + mailBody;\n" +
        "  const listHtml = withMissing.map(function(svc) {\n" +
        "    return '<p style=\"margin:14px 0 0 0;font-weight:700;font-size:13px;color:' + BLUE + ';font-family:' + FONT + ';\">' + serviceTitle(svc) + '</p>' +\n" +
        "      missingFieldsListHtml(svc);\n" +
        "  }).join('');\n" +
        "  return '<div style=\"border-top:1px solid #E5E7EB;font-size:1px;line-height:1px;margin:24px 0 20px 0;\">&nbsp;</div>' +\n" +
        "    '<table role=\"presentation\" style=\"width:100%;border-collapse:collapse;\">' +\n" +
        "    '<tr>' +\n" +
        "    '<td style=\"width:34px;vertical-align:top;padding-top:2px;\">' +\n" +
        "    '<img src=\"' + ICONS.question + '\" width=\"26\" height=\"26\" alt=\"' + L.questionAlt + '\" style=\"display:block;border:0;\" />' +\n" +
        "    '</td>' +\n" +
        "    '<td style=\"padding-left:12px;vertical-align:top;\">' +\n" +
        "    '<p style=\"margin:0;font-size:15px;line-height:1.5;color:' + NAVY + ';font-family:' + FONT + ';\">' + escapeHtml(introText) + '</p>' +\n" +
        "    listHtml +\n" +
        "    '<table role=\"presentation\" style=\"border-collapse:collapse;margin-top:14px;\"><tr><td>' +\n" +
        "    '<a href=\"' + mailHref + '\" style=\"display:inline-block;background:' + BLUE + ';color:#ffffff;text-decoration:none;font-weight:700;font-size:13px;padding:10px 18px;border-radius:6px;font-family:' + FONT + ';\">' +\n" +
        "    iconImg(ICONS.send, '', 13) + L.replyButton + '</a>' +\n" +
        "    '</td></tr></table>' +\n" +
        "    '<p style=\"margin:8px 0 0 0;font-size:11px;color:#5C7488;font-family:' + FONT + ';\">' + L.replyHelper + '</p>' +\n" +
        "    '</td>' +\n" +
        "    '</tr>' +\n" +
        "    '</table>' +\n" +
        "    '<div style=\"border-top:1px solid #E5E7EB;font-size:1px;line-height:1px;margin:20px 0 0 0;\">&nbsp;</div>';\n" +
        "}\n" +
        "\n" +
        "const signatureHtml =\n" +
        "  '<table role=\"presentation\" style=\"width:100%;border-collapse:collapse;\">' +\n" +
        "  '<tr>' +\n" +
        "  '<td width=\"59\" style=\"width:59px;vertical-align:middle;padding-right:14px;\">' +\n" +
        "  '<table role=\"presentation\" width=\"45\" height=\"45\" cellpadding=\"0\" cellspacing=\"0\" style=\"width:45px;height:45px;border-collapse:collapse;\">' +\n" +
        "  '<tr><td width=\"45\" height=\"45\" align=\"center\" valign=\"middle\" bgcolor=\"' + BLUE + '\" style=\"width:45px;height:45px;background:' + BLUE + ';border-radius:50%;color:#ffffff;font-size:18px;font-weight:700;font-family:' + FONT + ';text-align:center;\">M</td></tr>' +\n" +
        "  '</table>' +\n" +
        "  '</td>' +\n" +
        "  '<td style=\"vertical-align:middle;border-left:2px solid ' + BLUE + ';padding-left:14px;\">' +\n" +
        "  '<p style=\"margin:0;font-weight:700;font-size:16px;color:' + NAVY + ';font-family:' + FONT + ';\">Ing. Maritza Chávez</p>' +\n" +
        "  '<p style=\"margin:0;font-size:13px;color:#5C7488;font-family:' + FONT + ';\">' + L.jobTitle + '</p>' +\n" +
        "  '<p style=\"margin:4px 0 10px 0;font-weight:700;font-size:13px;color:' + BLUE + ';font-family:' + FONT + ';\">Transportes y Tours San Miguel Mágico</p>' +\n" +
        "  '<table role=\"presentation\" style=\"border-collapse:collapse;\"><tr>' +\n" +
        "  '<td style=\"padding:0 14px 0 0;font-size:11px;white-space:nowrap;font-family:' + FONT + ';\"><a href=\"mailto:contact@tripsanmiguel.com\" style=\"color:#5C7488;text-decoration:none;\">' + iconImg(ICONS.envelope, '', 13) + 'contact@tripsanmiguel.com</a></td>' +\n" +
        "  '<td style=\"padding:0 14px;font-size:11px;white-space:nowrap;font-family:' + FONT + ';\"><a href=\"tel:+5214151054985\" style=\"color:#5C7488;text-decoration:none;\">' + iconImg(ICONS.phone, '', 13) + '+52 (415) 105 4985</a></td>' +\n" +
        "  '<td style=\"padding:0 0 0 14px;font-size:11px;white-space:nowrap;font-family:' + FONT + ';\"><a href=\"http://tripsanmiguel.com/\" style=\"color:#5C7488;text-decoration:none;\">' + iconImg(ICONS.globe, '', 13) + 'tripsanmiguel.com</a></td>' +\n" +
        "  '</tr></table>' +\n" +
        "  '<table role=\"presentation\" style=\"border-collapse:collapse;margin-top:10px;\"><tr><td>' +\n" +
        "  '<a href=\"https://www.tripadvisor.com.mx/Attraction_Review-g151932-d12685278-Reviews-Transportes_y_Tours_San_Miguel_Magico-San_Miguel_de_Allende_Central_Mexico_and_G.html\" style=\"display:inline-block;background:' + LIGHTBLUE + ';color:' + BLUE + ';text-decoration:none;font-weight:700;font-size:11px;padding:7px 14px;border-radius:999px;font-family:' + FONT + ';\">' + iconImg(ICONS.star, '', 12) + L.tripadvisorLabel + '</a>' +\n" +
        "  '</td></tr></table>' +\n" +
        "  '</td>' +\n" +
        "  '</tr>' +\n" +
        "  '</table>';\n" +
        "\n" +
        "const html =\n" +
        "  '<style>@import url(\\'https://fonts.googleapis.com/css2?family=Roboto:wght@400;700&display=swap\\');</style>' +\n" +
        "  '<table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" style=\"background:#ffffff;\">' +\n" +
        "  '<tr><td align=\"center\" style=\"padding:8px 16px 0 16px;\">' +\n" +
        "  '<table role=\"presentation\" width=\"640\" cellpadding=\"0\" cellspacing=\"0\" style=\"width:100%;max-width:640px;\">' +\n" +
        "  '<tr><td style=\"padding:18px 4px 18px 4px;text-align:center;border-bottom:2px solid ' + BLUE + ';\">' +\n" +
        "  '<p style=\"margin:0;color:' + NAVY + ';font-size:17px;font-weight:700;letter-spacing:1px;font-family:' + SERIF + ';\">TRANSPORTES Y TOURS SAN MIGUEL MÁGICO</p>' +\n" +
        "  '<p style=\"margin:8px 0 0 0;color:' + DEEPBROWN + ';font-size:13px;font-style:italic;font-family:' + SERIF + ';\">' + L.headerTagline + '</p>' +\n" +
        "  '</td></tr>' +\n" +
        "  '<tr><td style=\"padding:24px 4px 30px 4px;font-family:' + FONT + ';color:' + NAVY + ';font-size:15px;line-height:1.6;\">' +\n" +
        "  '<p style=\"margin:0;\">' + escapeHtml(greeting) + '</p>' +\n" +
        "  '<p style=\"margin:14px 0 0 0;\">' + L.introLine + '</p>' +\n" +
        "  summaryHtml(services) +\n" +
        "  timelineHtml(services) +\n" +
        "  pendingHtml(missingIntro, services, originalSubject) +\n" +
        "  '<p style=\"margin:24px 0 0 0;\">' + escapeHtml(closing) + '</p>' +\n" +
        "  '<div style=\"border-top:1px solid #E5E7EB;font-size:1px;line-height:1px;margin:28px 0 22px 0;\">&nbsp;</div>' +\n" +
        "  signatureHtml +\n" +
        "  (orderRef ? '<p style=\"margin:16px 0 0 0;font-size:10px;color:#B7C0C7;font-family:' + FONT + ';\">' + L.orderRefLabel + ' ' + orderRef + '</p>' : '') +\n" +
        "  '</td></tr>' +\n" +
        "  '</table>' +\n" +
        "  '</td></tr>' +\n" +
        "  '<tr><td align=\"center\" style=\"padding:14px 16px 26px 16px;\">' +\n" +
        "  '<p style=\"margin:0;font-style:italic;font-size:12px;color:#6B7A85;font-family:' + FONT + ';\">' + L.footer + '</p>' +\n" +
        "  '</td></tr>' +\n" +
        "  '</table>';\n" +
        "\n" +
        "return { json: { reply_body_html: html } };\n"
    }
  },
  output: [{ reply_body_html: '<table role=\"presentation\">...</table>' }]
});

// ---------------------------------------------------------------------
// HTTP: registrar el mensaje saliente (la respuesta generada)
// ---------------------------------------------------------------------

const addMessageOutbound = node({
  type: 'n8n-nodes-base.httpRequest',
  version: 4.4,
  config: {
    name: 'Registrar Mensaje Saliente',
    parameters: {
      method: 'POST',
      url: SUPABASE_RPC_BASE + '/add_conversation_message',
      sendBody: true,
      contentType: 'json',
      specifyBody: 'json',
      jsonBody: {
        p_payload: {
          conversation_thread_id: expr('{{ $("Buscar o Crear Hilo de Conversación").first().json.data }}'),
          channel: 'EMAIL',
          message_type: 'EMAIL',
          direction: 'OUTBOUND',
          sender_name: 'Maritza - Transportes y Tours San Miguel Mágico',
          sender_email: 'contact@tripsanmiguel.com',
          recipient: expr('{{ $("Limpiar Correo").first().json.fromEmail }}'),
          subject: expr('RE: {{ $("Limpiar Correo").first().json.subject }}'),
          // Ya NO lleva prefijo .output. -- el predecesor inmediato ahora es
          // el nodo de código "Ensamblar Correo con Plantilla" (Code node
          // plano), no directamente el agente de IA.
          body_text: expr('{{ $json.reply_body_html }}'),
          body_html: expr('{{ $json.reply_body_html }}'),
          sent_at: expr('{{ $now.toISO() }}'),
          received_at: expr('{{ $now.toISO() }}'),
          ai_generated: true,
          reply_to_identifier: expr('{{ $("Limpiar Correo").first().json.internetMessageId }}'),
          raw_metadata: expr('{{ $("Clasificar y Extraer Reservación").first().json.output }}')
        }
      },
      authentication: 'genericCredentialType',
      genericAuthType: 'httpCustomAuth',
      // PostgREST devuelve valores escalares (uuid, boolean) como texto
      // plano, no como JSON válido (p.ej. un uuid sin comillas). Forzar
      // responseFormat:'text' evita que el nodo intente parsear JSON y
      // truene; el texto queda disponible en $json.data (confirmado en
      // ejecución real el 2026-07-21).
      options: { response: { response: { responseFormat: 'text' } } }
    },
    credentials: { httpCustomAuth: newCredential('Supabase Atlas API') }
  },
  output: [{ data: 'd0e1f2a3-0000-0000-0000-000000000000' }]
});

// ---------------------------------------------------------------------
// OUTLOOK: enviar la respuesta real al cliente
// ---------------------------------------------------------------------

const sendReply = node({
  type: 'n8n-nodes-base.microsoftOutlook',
  version: 2,
  config: {
    name: 'Responder Correo al Cliente',
    parameters: {
      resource: 'message',
      operation: 'reply',
      messageId: { __rl: true, mode: 'id', value: expr('{{ $("Limpiar Correo").first().json.messageId }}') },
      replyToSenderOnly: true,
      message: expr('{{ $("Ensamblar Correo con Plantilla").first().json.reply_body_html }}'),
      // bodyContentType vive dentro de additionalFields (solo visible con
      // replyToSenderOnly:true). Aunque la documentación dice que su
      // default ya es 'html', en la prueba real llegó como texto plano
      // con las etiquetas visibles -- hay que fijarlo explícitamente.
      additionalFields: { bodyContentType: 'html' },
      // Modo "borrador primero" mientras se gana confianza en la calidad
      // de las respuestas de Maritza: alguien del equipo revisa y da
      // "enviar" manualmente en Outlook. Cambiar a false para envío
      // automático una vez que se confíe en la calidad de las respuestas.
      options: { saveAsDraft: true }
    },
    credentials: { microsoftOutlookOAuth2Api: newCredential('Microsoft Outlook account') }
  },
  output: [{ id: 'AAMkAGI1AAB=', sentDateTime: '2026-07-21T15:05:00Z' }]
});

// =====================================================================
// NOTAS
// =====================================================================

const setupNote = sticky(
  '## Antes de activar\n\n' +
  '1. Crea la credencial **Supabase Atlas API** (tipo "Custom Auth"). Debe enviar en cada request:\n' +
  '```json\n{ "headers": { "apikey": "<tu llave nueva n8n_atlas_produccion>", "Authorization": "Bearer <tu llave nueva n8n_atlas_produccion>" } }\n```\n' +
  '2. Usa la llave nueva (n8n_atlas_produccion), nunca la "default" que estuvo expuesta.\n' +
  '3. Verifica el código ACCOUNT_TYPE usado ("INDIVIDUAL") contra tu catálogo real antes de la primera prueba.\n\n' +
  'Correo de la empresa (contact@tripsanmiguel.com) ya está cableado en los nodos de mensajería y ' +
  'find_or_create_conversation_thread / add_conversation_message ya están verificados contra el código real ' +
  'de Supabase (pg_get_functiondef, 2026-07-21).',
  [outlookTrigger, cleanEmail],
  { color: 4 }
);

// =====================================================================
// CONEXIONES
// =====================================================================

// Ronda 10 (2026-07-22): establece UNA sola vez la cadena completa que
// sigue después de resolver el id de orden -- patrón "fan-in" del SDK
// (ver get_sdk_reference). Tanto "Resolver Orden Existente" como
// "Resolver Orden Nueva" se conectan a este mismo "expandServices" más
// abajo; sus conexiones de salida (Expandir Servicios → Agregar Servicio →
// ... → Enviar Respuesta) solo necesitan definirse aquí una vez.
expandServices.to(
  addService.to(
    addMessageInbound.to(
      alertNewReservation.to(
        generateReply.to(assembleEmail.to(addMessageOutbound.to(sendReply)))
      )
    )
  )
);

cleanEmail.to(markAsRead);
cleanEmail.to(
  extractReservation.to(
    ifShouldContinue
      .onTrue(
        switchEngine
          .onCase(
            0,
            ifHasServices
              .onTrue(
                findOrCreatePerson
                  .to(
                    findOrCreateAccount.to(
                      findOrCreateThread.to(
                        checkOpenOrder.to(
                          ifThreadHasOpenOrder
                            .onTrue(resolveExistingOrder.to(expandServices))
                            .onFalse(
                              createServiceOrder.to(
                                attachOrderToThread.to(resolveNewOrder.to(expandServices))
                              )
                            )
                        )
                      )
                    )
                  )
              )
              .onFalse(alertManualReview)
          )
          .onCase(1, alertManualReview)
      )
      .onFalse(alertNotProcessed)
  )
);

export default workflow('atlas-flujo1-recepcion-v2', 'ATLAS - Recepción de Reservaciones (v2)')
  .add(outlookTrigger)
  .to(cleanEmail)
  .add(setupNote);
