Optimización CFE - Script

Este proyecto incluye un archivo .bat que ejecuta un script de
PowerShell con permisos suficientes sin requerir ejecución manual.

Archivos

-   Optimizacion-CFE_fixed2.ps1: Script principal de optimización.
-   run_optimizacion.bat: Ejecuta el script PowerShell con
    ExecutionPolicy Bypass.

Uso

1.  Coloca ambos archivos en la misma carpeta.
2.  Ejecuta run_optimizacion.bat con doble clic.
3.  El script PowerShell se abrirá automáticamente y realizará las
    optimizaciones.

Seguridad

El script no elimina archivos del sistema ni modifica configuraciones
críticas.
Todas las limpiezas realizadas son seguras y se limitan a: - Cachés
temporales - Archivos residuales - Componentes obsoletos no esenciales

Notas

-   PowerShell requiere la opción -ExecutionPolicy Bypass para permitir
    la ejecución del script.
-   No es necesario ejecutarlo como administrador si el script está
    diseñado para operaciones sin privilegios elevados.
