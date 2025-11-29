Guía de Pruebas - Optimize-CFE.ps1
Esta guía te ayudará a probar el script de optimización en tu Máquina Virtual (VM) de forma segura y verificar los resultados.

1. Preparación del Entorno
Copia el archivo 
Optimize-CFE.ps1
 a tu VM (por ejemplo, al Escritorio).
Abre PowerShell como Administrador.
Clic derecho en Inicio -> Windows PowerShell (Administrador).
Habilita la ejecución de scripts (si es necesario):
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
2. Prueba en Modo Seguro (DryRun)
Lo primero es ejecutar el script en modo simulación. Esto NO hará cambios, solo te mostrará qué haría.

.\Optimize-CFE.ps1 -DryRun -ShowConsoleSummary -DeepClean -RemoveBloatware
Qué verificar:
Revisa la consola: ¿Muestra archivos detectados? ¿Muestra apps de bloatware que eliminaría?
Revisa el Log: El script te dirá dónde guardó el log (por defecto C:\CFE_Logs). Ábrelo y lee las líneas que dicen [DRYRUN].
3. Prueba Real (Ejecución)
Una vez confiado con el DryRun, ejecuta el script real. Puedes probar diferentes niveles de limpieza.

Nivel 1: Limpieza Básica (Segura)
Solo temporales y optimización de energía.

.\Optimize-CFE.ps1 -ShowConsoleSummary
Nivel 2: Limpieza Completa (WinUtil style)
Incluye vaciado de papelera, DNS y eliminación de bloatware.

.\Optimize-CFE.ps1 -DeepClean -RemoveBloatware -ShowConsoleSummary
4. Verificación de Resultados (Logs)
El script genera automáticamente un registro detallado de todas las acciones.

Ubicación por defecto: C:\CFE_Logs\
Nombre del archivo: CFE_Optimize_YYYYMMDD_HHMMSS.log
Contenido del Log:
[INFO]: Acciones normales (archivos borrados, servicios detenidos).
[WARN]: Advertencias (ej. si no eres admin o no se encontró algo).
[ERROR]: Fallos específicos (ej. archivo en uso que no se pudo borrar).
Ejemplo de lectura de Log
[2023-11-29 15:30:00] [INFO] Iniciando limpieza de archivos temporales...
[2023-11-29 15:30:01] [INFO] Eliminado: C:\Windows\Temp\archivo_viejo.tmp
[2023-11-29 15:30:05] [INFO] Servicio optimizado (Detenido/Deshabilitado): DiagTrack
[2023-11-29 15:30:10] [INFO] === FIN DEL PROCESO ===
[2023-11-29 15:30:10] [INFO] Espacio Liberado: 1.50 GB
