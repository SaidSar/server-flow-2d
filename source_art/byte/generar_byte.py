"""
Genera los dibujos de BYTE (el asistente) de Server Flow 2D: cabeza esférica blanca y naranja, visor con ojos
luminosos, orejas en cono y punta de taladro. Cuatro expresiones: normal, contenta, preocupada y alerta (ataque DDoS).
Estilo 2D con contorno oscuro y sombra suave, como Briseida (no vienen de Blender).

Uso: python3 source_art/byte/generar_byte.py
  - escribe los SVG en source_art/byte/svg/ (la fuente editable)
  - si hay Playwright instalado, renderiza los PNG de 512x512 con fondo transparente en
    assets/art/characters/byte/byte_<expresion>.png (ruta en Paths.BYTE_BUST)
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
SVG_DIR = os.path.join(HERE, "svg")
PNG_DIR = os.path.join(HERE, "..", "..", "assets", "art", "characters", "byte")
MOODS = ("normal", "contenta", "preocupada", "alerta")
SIZE = 512

OUT="#2a1c22"; OR="#ff8a1f"; OR_D="#d9650a"; OR_L="#ffb04d"; WH="#fcf9f5"; SH="#ecdfd2"; VI="#2b1e36"
def byte_svg(uid: str, mood: str = "normal", label: bool = False) -> str:
    ec=OR_L; rim=OR
    c=f"c{uid}"
    if mood=="normal":
        eyes=f'''<path d="M141 248 A19 19 0 0 1 179 248" /><path d="M221 248 A19 19 0 0 1 259 248" />'''
        extra=""
    elif mood=="contenta":
        eyes=f'''<path d="M139 250 A21 21 0 0 1 181 250" /><path d="M219 250 A21 21 0 0 1 261 250" />'''
        extra=f'<path d="M184 266 Q200 282 216 266" fill="none" stroke="{OR_L}" stroke-width="7" stroke-linecap="round" filter="url(#g{uid})"/><ellipse cx="118" cy="262" rx="9" ry="5" fill="{OR}" opacity=".55"/><ellipse cx="282" cy="262" rx="9" ry="5" fill="{OR}" opacity=".55"/>'
    elif mood=="preocupada":
        eyes=f'''<circle cx="160" cy="240" r="10" fill="{OR_L}" stroke="none"/><circle cx="240" cy="240" r="10" fill="{OR_L}" stroke="none"/><circle cx="157" cy="237" r="3.5" fill="#fff" stroke="none"/><circle cx="237" cy="237" r="3.5" fill="#fff" stroke="none"/>'''
        extra=f'<path d="M140 220 L176 208" stroke="{OR_L}" stroke-width="7" stroke-linecap="round" fill="none" filter="url(#g{uid})"/><path d="M224 208 L260 220" stroke="{OR_L}" stroke-width="7" stroke-linecap="round" fill="none" filter="url(#g{uid})"/><path d="M178 268 Q200 260 222 268" fill="none" stroke="{OR_L}" stroke-width="6" stroke-linecap="round" filter="url(#g{uid})"/>'
        extra+=f'<path d="M318 150 Q330 172 318 184 Q304 172 318 150 Z" fill="#bfe6ff" stroke="{OUT}" stroke-width="3.5" stroke-linejoin="round"/><path d="M314 172 Q313 177 317 179" stroke="#fff" stroke-width="2.5" fill="none" stroke-linecap="round"/>'
    else:
        ec="#ff5a64"; rim="#ff3b4a"
        eyes=f'''<circle cx="160" cy="242" r="13" fill="{ec}" stroke="none"/><circle cx="240" cy="242" r="13" fill="{ec}" stroke="none"/><circle cx="160" cy="242" r="5" fill="#fff" stroke="none"/><circle cx="240" cy="242" r="5" fill="#fff" stroke="none"/>'''
        extra=f'<path d="M138 212 L180 224" stroke="{ec}" stroke-width="8" stroke-linecap="round" fill="none" filter="url(#g{uid})"/><path d="M220 224 L262 212" stroke="{ec}" stroke-width="8" stroke-linecap="round" fill="none" filter="url(#g{uid})"/><path d="M176 272 L224 272" stroke="{ec}" stroke-width="7" stroke-linecap="round" fill="none" filter="url(#g{uid})"/>'
        extra+=f'<g transform="translate(318 96)" fill="#ff3b4a" stroke-width="4"><path d="M-9 -34 L9 -34 L5 -4 L-5 -4 Z"/><circle cx="0" cy="8" r="7"/></g><g transform="translate(350 118) scale(.7)" fill="#ff3b4a" stroke-width="5"><path d="M-9 -34 L9 -34 L5 -4 L-5 -4 Z"/><circle cx="0" cy="8" r="7"/></g>'
    txt=f'<text x="200" y="160" text-anchor="middle" transform="rotate(-6 200 160)" font-family="Permanent Marker, Marker Felt, Comic Sans MS, cursive" font-size="30" fill="{OR}" stroke="{OUT}" stroke-width="1.4" paint-order="stroke" letter-spacing="2">BYTE</text>' if label else ""
    return f'''<svg viewBox="0 10 400 400" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="BYTE, expresión {mood}">
<defs><clipPath id="{c}"><circle cx="200" cy="220" r="118"/></clipPath>
<filter id="g{uid}" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur stdDeviation="3.2" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter></defs>
<g stroke="{OUT}" stroke-width="5" stroke-linejoin="round" stroke-linecap="round">
 <!-- drill -->
 <path d="M176 326 L224 326 L200 396 Z" fill="{OR}"/><path d="M186 352 L214 352 M191 372 L209 372" stroke="{WH}" stroke-width="5" fill="none"/>
 <!-- ears -->
 <path d="M38 40 L172 138 L90 222 Z" fill="{WH}"/><path d="M38 40 L172 138 L150 160 Z" fill="{SH}" stroke="none"/><path d="M38 40 L172 138 L90 222 Z" fill="none"/>
 <path d="M62 84 L150 150 L104 196 Z" fill="{OR}" stroke-width="4"/>
 <path d="M340 66 L290 134 L336 196 Z" fill="{WH}"/><path d="M332 100 L304 138 L330 172 Z" fill="{OR}" stroke-width="4"/>
 <!-- head -->
 <circle cx="200" cy="220" r="118" fill="{WH}"/>
 <g clip-path="url(#{c})" stroke="none"><rect x="70" y="90" width="260" height="260" fill="{SH}"/><circle cx="184" cy="204" r="118" fill="{WH}"/>
  <path d="M236 98 Q316 130 330 214" fill="none" stroke="{OR}" stroke-width="26"/><path d="M226 112 Q304 142 316 220" fill="none" stroke="{OR_D}" stroke-width="3" opacity=".6"/>
  <path d="M82 300 Q150 340 230 336" fill="none" stroke="{OR}" stroke-width="18"/></g>
 <circle cx="200" cy="220" r="118" fill="none"/>
 <!-- speaker -->
 <circle cx="104" cy="170" r="14" fill="#d9d0c6" stroke-width="4"/><circle cx="104" cy="170" r="6" fill="{VI}" stroke="none"/><circle cx="104" cy="170" r="14" fill="none" stroke="{OR}" stroke-width="2" opacity="0"/>
 <!-- visor -->
 <ellipse cx="200" cy="240" rx="98" ry="66" fill="{rim}" stroke-width="5"/><ellipse cx="200" cy="240" rx="88" ry="57" fill="{VI}" stroke-width="4"/>
 <path d="M124 214 Q146 192 184 188" fill="none" stroke="#fff" stroke-opacity=".38" stroke-width="5"/>
 <g fill="none" stroke="{ec}" stroke-width="11" filter="url(#g{uid})">{eyes}</g>
 {extra}
</g>
{txt}
<ellipse cx="146" cy="136" rx="20" ry="7" transform="rotate(-38 146 136)" fill="#fff" opacity=".9"/><circle cx="168" cy="118" r="3.5" fill="#fff" opacity=".9"/>
</svg>'''


def main() -> None:
    os.makedirs(SVG_DIR, exist_ok=True)
    os.makedirs(PNG_DIR, exist_ok=True)
    for mood in MOODS:
        with open(os.path.join(SVG_DIR, "byte_%s.svg" % mood), "w", encoding="utf-8") as f:
            f.write(byte_svg(mood[:2], mood))
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print("SVG listos. Sin Playwright no se renderizan los PNG (pip install playwright).")
        return
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(viewport={"width": SIZE, "height": SIZE})
        for mood in MOODS:
            svg = byte_svg(mood[:2], mood).replace("<svg ", '<svg width="%d" height="%d" ' % (SIZE, SIZE), 1)
            page.set_content("<body style='margin:0;background:transparent'>%s</body>" % svg)
            page.screenshot(path=os.path.join(PNG_DIR, "byte_%s.png" % mood), omit_background=True)
        browser.close()
    print("PNG de BYTE listos en", os.path.normpath(PNG_DIR))


if __name__ == "__main__":
    main()
