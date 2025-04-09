#!/bin/bash

# === Configuración inicial ===
FECHA=$(date '+%Y-%m-%d_%H-%M-%S')
HTML_REPORT="informe_dispositivo_$FECHA.html"

read -p "🔍 Ingrese la dirección IP del dispositivo a analizar: " IP_OBJETIVO

# === Verificar conectividad ===
echo "[+] Verificando conectividad con $IP_OBJETIVO..."
ping -c 2 $IP_OBJETIVO > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo "[!] ❌ Dispositivo sin conexión. No responde al ping."
    CONECTADO="no"
else
    echo "[+] ✅ Dispositivo conectado."
    CONECTADO="si"
fi

# === Si está conectado, iniciar escaneos ===
if [[ "$CONECTADO" == "si" ]]; then

    echo "[+] 🔍 Escaneando puertos abiertos..."
    PORT_SCAN=$(nmap --top-ports 20 $IP_OBJETIVO)
    PUERTOS_ABIERTOS=$(echo "$PORT_SCAN" | grep "open" | wc -l)

    echo "[+] 🧪 Escaneando vulnerabilidades..."
    VULN_SCAN=$(nmap -sV --script vuln $IP_OBJETIVO)

    # === Clasificación de criticidad y extracción de detalles ===
    UMBRAL="Normal"
    VULN_DETALLES=""

    if echo "$VULN_SCAN" | grep -q "VULNERABLE"; then
        UMBRAL="Crítico"
        VULN_DETALLES=$(echo "$VULN_SCAN" | grep -A 10 "VULNERABLE" | sed 's/^/    /')
    elif echo "$VULN_SCAN" | grep -q "CVE" && echo "$VULN_SCAN" | grep -q "HIGH"; then
        UMBRAL="Crítico"
        VULN_DETALLES=$(echo "$VULN_SCAN" | grep -A 10 "CVE" | sed 's/^/    /')
    elif echo "$VULN_SCAN" | grep -q "MEDIUM"; then
        UMBRAL="Alto"
        VULN_DETALLES=$(echo "$VULN_SCAN" | grep -A 5 "CVE" | sed 's/^/    /')
    elif echo "$VULN_SCAN" | grep -q "Potentially"; then
        UMBRAL="Medio"
        VULN_DETALLES=$(echo "$VULN_SCAN" | grep -A 5 "Potentially" | sed 's/^/    /')
    else
        VULN_DETALLES="    No se detectaron vulnerabilidades relevantes."
    fi

    echo "[+] ✅ Análisis completado. Nivel de riesgo: $UMBRAL"

else
    PUERTOS_ABIERTOS="N/A"
    VULN_SCAN="No se pudo analizar. Dispositivo sin conexión."
    UMBRAL="Sin conexión"
    VULN_DETALLES="    El dispositivo no responde a peticiones."
    PORT_SCAN="No disponible"
fi

# === Generar reporte HTML ===
echo "[+] Generando reporte HTML..."

{
echo "<!DOCTYPE html><html lang='es'><head><meta charset='UTF-8'>"
echo "<title>Informe de Análisis - $IP_OBJETIVO</title>"
echo "<style>
body { font-family: Arial, sans-serif; background: #f4f4f4; padding: 20px; }
h1 { color: #333; }
section { background: white; padding: 15px; margin-bottom: 20px; border-radius: 5px; box-shadow: 0 0 5px #ccc; }
.good { color: green; font-weight: bold; }
.warn { color: orange; font-weight: bold; }
.high { color: orangered; font-weight: bold; }
.critical { color: red; font-weight: bold; }
pre { background: #eee; padding: 10px; border-radius: 5px; overflow-x: auto; white-space: pre-wrap; }
</style></head><body>"

echo "<h1>📋 Informe de Análisis de Dispositivo</h1>"
echo "<p><strong>Fecha:</strong> $FECHA</p>"
echo "<p><strong>IP Analizada:</strong> $IP_OBJETIVO</p>"

echo "<section><h2>📶 Conectividad</h2>"
if [[ "$CONECTADO" == "si" ]]; then
    echo "<p class='good'>✅ Dispositivo conectado correctamente.</p>"
else
    echo "<p class='critical'>❌ El dispositivo no responde. Sin conexión.</p>"
fi
echo "</section>"

echo "<section><h2>🔍 Puertos abiertos</h2>"
if [[ "$CONECTADO" == "si" ]]; then
    echo "<p>Se encontraron <strong>$PUERTOS_ABIERTOS</strong> puertos abiertos.</p>"
    echo "<pre>$(echo "$PORT_SCAN" | grep 'open')</pre>"
else
    echo "<p>No se pudo realizar escaneo de puertos.</p>"
fi
echo "</section>"

echo "<section><h2>🧪 Vulnerabilidades detectadas</h2>"
echo "<pre>$VULN_DETALLES</pre>"
echo "</section>"

echo "<section><h2>⚠ Nivel de Riesgo Detectado</h2>"
case "$UMBRAL" in
    "Normal")
        echo "<p class='good'>✅ Nivel: $UMBRAL</p>" ;;
    "Medio")
        echo "<p class='warn'>⚠ Nivel: $UMBRAL</p>" ;;
    "Alto")
        echo "<p class='high'>🟠 Nivel: $UMBRAL</p>" ;;
    "Crítico")
        echo "<p class='critical'>🚨 Nivel: $UMBRAL</p>" ;;
    "Sin conexión")
        echo "<p class='critical'>❌ No se pudo analizar el dispositivo.</p>" ;;
esac
echo "</section>"

echo "<footer><p>🛠️ Generado por el script de auditoría - $(hostname)</p></footer>"
echo "</body></html>"
} > "$HTML_REPORT"

echo "[+] ✅ Informe HTML generado exitosamente: $HTML_REPORT"
