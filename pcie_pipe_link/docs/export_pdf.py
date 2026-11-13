"""Export DESIGN.md using Pandoc and a local headless Chromium browser."""
import argparse
from pathlib import Path
import re
import shutil
import subprocess
import base64
import json
import websocket


BASE = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--browser', default='C:/Program Files/Google/Chrome/Application/chrome.exe')
    parser.add_argument('--pandoc', default=shutil.which('pandoc'))
    parser.add_argument('--preview', action='store_true')
    parser.add_argument('--output', default='DESIGN.pdf')
    args = parser.parse_args()
    build = BASE / 'build' / 'pdf'
    build.mkdir(parents=True, exist_ok=True)
    diagram = build / 'controller_connection.svg'
    diagram.write_text('''<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="160" viewBox="0 0 1000 160">
<defs><marker id="arrow" markerWidth="8" markerHeight="8" refX="5" refY="3" orient="auto-start-reverse"><path d="M0,0 L6,3 L0,6" fill="none" stroke="#245da8" stroke-width="1.5"/></marker></defs>
<rect width="1000" height="160" fill="white"/>
<g fill="#f4f7fb" stroke="#245da8" stroke-width="2">
<rect x="10" y="45" width="270" height="70" rx="6"/>
<rect x="365" y="45" width="270" height="70" rx="6"/>
<rect x="720" y="45" width="270" height="70" rx="6"/>
</g>
<g stroke="#245da8" stroke-width="2" marker-start="url(#arrow)" marker-end="url(#arrow)">
<path d="M291,80 H354"/><path d="M646,80 H709"/>
</g>
<g fill="#233247" font-family="Arial,sans-serif" font-size="23" text-anchor="middle">
<text x="145" y="88">huixi_g4x4(dsp)</text><text x="500" y="88">pcie_pipe_link</text><text x="855" y="88">huixi_g4x4(usp)</text>
</g></svg>''', encoding='utf-8')
    source = (BASE / 'DESIGN.md').read_text(encoding='utf-8')
    source = re.sub(r'```mermaid\n.*?```',
                    f'![Example controller connection]({diagram.as_posix()})', source, flags=re.S)
    md = build / 'DESIGN.print.md'
    md.write_text(source, encoding='utf-8')
    html = build / 'DESIGN.html'
    result = subprocess.run([args.pandoc, str(md), '--from=gfm', '--to=html5', '--standalone',
                    '--embed-resources', '--resource-path=' + str(BASE),
                    '--metadata=title:pcie_pipe_link',
                    '--css=' + str(BASE / 'docs' / 'pdf.css')], check=True, capture_output=True)
    html.write_bytes(result.stdout)
    # Keep each image with its caption when printing.
    body = html.read_text(encoding='utf-8')
    body = re.sub(r'(<p><img\b.*?</p>\s*<p><em>Figure.*?</em></p>)',
                  r'<div class="figure-block">\1</div>', body, flags=re.S)
    body = re.sub(r'(<h4 id="[^"]*(?:preset-to-coefficient-conversion-timing|receiver-equalization-evaluation-timing)".*?)(?=<h4|</body>)',
                  r'<div class="timing-section">\1</div>', body, flags=re.S)
    html.write_text(body, encoding='utf-8')
    pdf = BASE / args.output
    process = subprocess.Popen([args.browser, '--headless', '--disable-gpu', '--no-first-run',
                                '--allow-file-access-from-files', '--remote-debugging-port=0',
                                '--user-data-dir=' + str(build / 'browser-profile'), 'about:blank'],
                               stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True,
                               creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    try:
        for line in process.stderr:
            if 'DevTools listening on ' in line:
                address = line.strip().split('DevTools listening on ', 1)[1]
                break
        else:
            raise RuntimeError('Browser debugging endpoint unavailable')
        ws = websocket.create_connection(address, timeout=45, suppress_origin=True)
        sequence = 0

        def call(method, params=None, session=None):
            nonlocal sequence
            sequence += 1
            message = {'id': sequence, 'method': method, 'params': params or {}}
            if session:
                message['sessionId'] = session
            ws.send(json.dumps(message))
            while True:
                reply = json.loads(ws.recv())
                if reply.get('id') == sequence:
                    if 'error' in reply:
                        raise RuntimeError(reply['error'])
                    return reply.get('result', {})

        target = call('Target.createTarget', {'url': 'about:blank'})['targetId']
        session = call('Target.attachToTarget', {'targetId': target, 'flatten': True})['sessionId']
        call('Page.enable', session=session)
        call('Page.navigate', {'url': html.as_uri()}, session)
        expression = '''(async () => {
            if (document.readyState !== 'complete') await new Promise(r => window.addEventListener('load', r, {once:true}));
            await document.fonts.ready;
            return [...document.images].every(i => i.complete && i.naturalWidth > 0);
        })()'''
        loaded = call('Runtime.evaluate', {'expression': expression, 'awaitPromise': True,
                                          'returnByValue': True}, session)
        assert loaded['result'].get('value') is True, 'Figure loading failed'
        result = call('Page.printToPDF', {'printBackground': True, 'preferCSSPageSize': True,
                                         'displayHeaderFooter': False}, session)
        pdf_bytes = base64.b64decode(result['data'])
        if args.preview:
            import pypdfium2 as pdfium
            from PIL import Image, ImageDraw
            document = pdfium.PdfDocument(pdf_bytes)
            pages = len(document)
            contact = Image.new('RGB', (3 * 260, ((pages + 2) // 3) * 390), '#dce3ec')
            draw = ImageDraw.Draw(contact)
            texts = []
            for index in range(pages):
                page = document[index]
                texts.append(page.get_textpage().get_text_range())
                preview = page.render(scale=1.1).to_pil().convert('RGB')
                preview.save(build / f'page-{index + 1:02}.png')
                preview.thumbnail((246, 352))
                x, y = (index % 3) * 260 + 7, (index // 3) * 390 + 24
                contact.paste(preview, (x, y))
                draw.text((x, y - 17), f'Page {index + 1}', fill='#233247')
            contact.save(build / 'contact-sheet.png')
            text = '\n'.join(texts)
            (build / 'extracted-text.txt').write_text(text, encoding='utf-8')
            assert all(t.strip() for t in texts), 'Blank PDF page'
            assert not re.search(r'[\u4e00-\u9fff]', text), 'Untranslated text'
            assert '3.3.3 Receiver Equalization Evaluation Timing' in ' '.join(text.split())
            print(f'Validated {pages} PDF pages; previews generated')
        pdf.write_bytes(pdf_bytes)
        ws.close()
    finally:
        process.terminate()
        process.wait(timeout=10)
    assert pdf.is_file() and pdf.read_bytes().startswith(b'%PDF-'), 'PDF export failed'
    print(f'Exported {pdf} ({pdf.stat().st_size:,} bytes)')


if __name__ == '__main__':
    main()
