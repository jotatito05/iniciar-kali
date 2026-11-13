# Iniciar Kali

Abre `Iniciar-Kali.bat` con doble clic. Si ya tienes Kali en WSL, te abre la terminal. Si no, sale un menú para instalarlo o usar Docker Desktop.

```bat
Iniciar-Kali.bat --wsl
Iniciar-Kali.bat --docker
Iniciar-Kali.bat --docker --ephemeral
```

Con Docker puedes usar `--workdir "C:\ruta\proyecto"` para elegir qué carpeta aparece en `/workspace`. Los cambios que hagas ahí se guardan en Windows, incluso con `--ephemeral`. Si ya existe el contenedor, usa otro nombre con `--container` para cambiar la carpeta.

Para ver todas las opciones, ejecuta `Iniciar-Kali.bat --help`.
