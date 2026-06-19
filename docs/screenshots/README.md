# README screenshots — cómo capturarlas

Las imágenes del README deben ser **capturas reales de la app** (SwiftUI/macOS).  
No uses mockups generados: la fuente, bordes y controles deben ser los de macOS.

## 1. Cargar datos de demo

```bash
./GrafanaScope/scripts/load-demo-config.sh
open ~/Applications/Grafana\ Scope.app
```

Eso deja instancias **Production** / **Staging** con URLs `*.example.com` (solo en tu Mac, no en el repo).

**Restaurar tu config real** (si corriste demo antes):

```bash
./GrafanaScope/scripts/restore-config-backup.sh
```

Si no hay backup, vuelve a añadir instancias en Settings → Instances.

## 2. Captura cada pantalla

Guarda PNG en esta carpeta con **estos nombres exactos**:

| Archivo | Qué capturar |
|---------|----------------|
| `source-alerts.png` | Panel de alertas completo (sin barra de menú del sistema, o recortada) |
| `source-menubar.png` | Solo la zona del icono rayo en la barra de menú (recorte estrecho) |
| `source-settings-general.png` | Ventana Settings → pestaña General |
| `source-settings-instances.png` | Settings → Instances, instancia Production seleccionada |
| `source-settings-add.png` | Settings → Instances → botón + (New instance) |
| `source-settings-menu.png` | Menú del engranaje (dropdown) |

**Tips**
- Modo oscuro de macOS (como en la app).
- Oculta iconos ajenos en la barra de menú si puedes (Control Center → mostrar solo lo necesario), o pásanos un recorte muy estrecho del rayo.
- No incluyas tokens reales: usa `load-demo-config.sh` antes de capturar.

## 3. Generar assets para el README

```bash
python3 GrafanaScope/scripts/prepare-readme-screenshots.py
```

El script **solo recorta y renombra** — no redibuja la UI.

## 4. Alternativa

Pásame las capturas en el chat (como antes). Las procesamos con recorte mínimo y las dejamos en `docs/screenshots/`.
