# Iniciar Kali

Lanzador de Kali Linux para Windows con WSL o Docker Desktop. Sin argumentos, abre Kali si ya está registrada en WSL; si no, muestra el menú.

```bat
Iniciar-Kali.bat --help
Iniciar-Kali.bat --wsl --dry-run
Iniciar-Kali.bat --wsl
Iniciar-Kali.bat --docker --ephemeral
```

La instalación mediante WSL puede pedir permisos de administrador y requerir un reinicio. Para Docker, necesitas Docker Desktop.

Docker monta la carpeta actual (o la indicada con `--workdir`) en `/workspace` con permiso de escritura. Los cambios en esa carpeta siguen en Windows incluso al salir de un contenedor efímero. Un contenedor persistente ya creado conserva su montaje, red y comando inicial. Usa otro nombre con `--container` si necesitas una configuración distinta.
