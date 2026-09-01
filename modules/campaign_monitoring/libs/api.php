<?php


include_once dirname(__DIR__).'/configs/default.conf.php';
$databaseConfig = parse_url($arrConfModule['cadena_dsn']);
if (!is_array($databaseConfig) ||
    !isset($databaseConfig['host']) ||
    !isset($databaseConfig['user']) ||
    !isset($databaseConfig['pass']) ||
    !isset($databaseConfig['path']) ||
    $databaseConfig['path'] === '/') {
    http_response_code(500);
    die("Invalid campaign monitoring database configuration");
}

$DBHOST = $databaseConfig['host'];
$DBNAME = ltrim($databaseConfig['path'], '/');
$DBUSER = $databaseConfig['user'];
$DBPASS = $databaseConfig['pass'];


$conn = new mysqli($DBHOST, $DBUSER, $DBPASS, $DBNAME);

// Verificar la conexión
if ($conn->connect_error) {
    die("Error de conexión: " . $conn->connect_error);
}

// Obtener el parámetro id_campaign de la URL
    if (isset($_GET['id_campaignIncoming'])){

        $id_campaign = $_GET['id_campaignIncoming'];

        // Preparar la consulta SQL con un marcador de posición para evitar la inyección de SQL
        $sql = "SELECT
                    /*ce.id_agent,*/
                    CONCAT(a.type, '/', a.number) AS agent,
                    MAX(ce.datetime_end) AS lastCall,
                    ce.id_campaign
                FROM
                    call_entry ce
                JOIN
                    agent a ON ce.id_agent = a.id
                WHERE
                    ce.id_campaign = ?
                GROUP BY
                    ce.id_agent, a.type, a.number, ce.id_campaign";

        $stmt = $conn->prepare($sql);
        $stmt->bind_param("i", $id_campaign);
        $stmt->execute();

        // Obtener resultados y almacenarlos en un array asociativo
        $stmt->bind_result($agent, $lastCall, $id_campaign);
        $listaLastCall = array();

        while ($stmt->fetch()) {
            $listaLastCall[] = array(
                'agent' => $agent,
                'lastCall' => $lastCall,
                'id_campaign' => $id_campaign,
            );
        }


        // Cerrar la conexión
        $stmt->close();
        $conn->close();

        $queueNumber        = $_GET['queue'];
        $command            = "asterisk -rx 'queue show $queueNumber' | grep 'Unavailable' | awk -F'[()]' '{print $2}'";
        $resultUnavailable  = shell_exec($command);

        $lines = explode("\n", trim($resultUnavailable));
        // Elimina líneas vacías
        $lines = array_filter($lines);
        $unavailables = array();
        foreach ($lines as $line) {
        // Almacena la información en el array con la clave "agent"
            $unavailables[] = array(
                'agent' => trim($line),
            );
        }

        $data['listaLastCall'] = $listaLastCall;
        $data['unavailables'] = $unavailables;
        // Devolver el resultado como JSON
        header('Content-Type: application/json');
        echo json_encode($data);

    }

    if (isset($_GET['id_campaignOutgoing'])){

        $id_campaign = $_GET['id_campaignOutgoing'];

        // Preparar la consulta SQL con un marcador de posición para evitar la inyección de SQL
        $sql = "SELECT
                    /*c.id_agent,*/
                    CONCAT(a.type, '/', a.number) AS agent,
                    MAX(c.end_time) AS lastCall,
                    c.id_campaign
                FROM
                    calls c
                JOIN
                    agent a ON c.id_agent = a.id
                WHERE
                    c.id_campaign = ?
                GROUP BY
                    c.id_agent, a.type, a.number, c.id_campaign";

        $stmt = $conn->prepare($sql);
        $stmt->bind_param("i", $id_campaign);
        $stmt->execute();

        // Obtener resultados y almacenarlos en un array asociativo
        $result = $stmt->get_result();
        $listaLastCall = array();

        while ($row = $result->fetch_assoc()) {
            $listaLastCall[] = $row;
        }

        // Cerrar la conexión
        $stmt->close();
        $conn->close();

        $queueNumber        = $_GET['queue'];
        $command            = "asterisk -rx 'queue show $queueNumber' | grep 'Unavailable' | awk -F'[()]' '{print $2}'";
        $resultUnavailable  = shell_exec($command);

        $lines = explode("\n", trim($resultUnavailable));
        // Elimina líneas vacías
        $lines = array_filter($lines);
        $unavailables = array();
        foreach ($lines as $line) {
         // Almacena la información en el array con la clave "agent"
            $unavailables[] = array(
                'agent' => trim($line),
            );
        }

        $data['listaLastCall'] = $listaLastCall;
        $data['unavailables'] = $unavailables;
        // Devolver el resultado como JSON
        header('Content-Type: application/json');
        echo json_encode($data);

    }
