<?php

// Este endpoint directo fue retirado. Las solicitudes de monitoreo deben pasar
// por el despachador autenticado de módulos de Issabel.
// This direct endpoint is retired. Monitoring requests must pass through
// Issabel's authenticated module dispatcher.
http_response_code(410);
header('Content-Type: application/json');
echo json_encode(array(
    'status' => 'error',
    'message' => 'This endpoint is no longer available',
));
