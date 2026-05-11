# ComfyUI + Flux + zhangp365 PuLID + 4 검증 패치 — volume mask 회피용 v2
FROM runpod/comfyui:latest

# /opt에 PuLID 박음 (volume 마운트와 무관한 경로)
RUN mkdir -p /opt/pulid-bundle \
 && cd /opt/pulid-bundle \
 && git clone https://github.com/zhangp365/ComfyUI-PuLID-Flux.git \
 && cd ComfyUI-PuLID-Flux \
 && git checkout 191cd99775

# 패치 1: zhangp365 forward_orig **kwargs
RUN python3 -c "p='/opt/pulid-bundle/ComfyUI-PuLID-Flux/pulidflux.py'; \
src=open(p).read(); \
old='attn_mask: Tensor = None,\n    ) -> Tensor:'; \
new='attn_mask: Tensor = None,\n        **kwargs,\n    ) -> Tensor:'; \
src = src.replace(old, new, 1) if old in src else src; \
open(p,'w').write(src); \
print('patch1 done')"

# pip deps (container disk — image layer에 박힘)
RUN pip install --no-cache-dir facexlib insightface onnxruntime onnxruntime-gpu ftfy timm

# entrypoint script: 부팅 시 volume에 PuLID 복사 + lldacing 패치 적용
RUN cat > /opt/init-pulid.sh <<'EOF'
#!/bin/bash
set -e

# 1) PuLID custom_node 복사 (이미 있으면 스킵)
DEST=/workspace/runpod-slim/ComfyUI/custom_nodes/ComfyUI-PuLID-Flux
mkdir -p "$(dirname $DEST)"
if [ ! -f "$DEST/pulidflux.py" ]; then
  cp -r /opt/pulid-bundle/ComfyUI-PuLID-Flux "$DEST"
  echo "[init] PuLID 복사 완료 → $DEST"
else
  echo "[init] PuLID 이미 있음 (스킵)"
fi

# 2) lldacing PuLID 패치 (runpod-slim 이미지에 기본 설치돼있을 수 있음)
python3 <<'PYEOF'
import os, re
base = '/workspace/runpod-slim/ComfyUI/custom_nodes'
patches = [
    ('comfyui_pulid_flux_ll/pulidflux.py', ['pulid_outer_sample_wrappers_with_override','pulid_outer_sample_wrappers']),
    ('comfyui_pulid_flux_ll/PulidFluxHook.py', ['pulid_forward_orig']),
]
for f, fns in patches:
    p = os.path.join(base, f)
    if not os.path.exists(p):
        continue
    with open(p) as fp: src = fp.read()
    orig = src
    for fn in fns:
        pat = re.compile(r'(def ' + fn + r'\([^)]+?)(\)\s*(?:->[^:]+)?\s*:)', re.DOTALL)
        def repl(m):
            if '**kwargs' in m.group(1): return m.group(0)
            return m.group(1) + ', **kwargs' + m.group(2)
        src = pat.sub(repl, src)
    if src != orig:
        with open(p,'w') as fp: fp.write(src)
        print(f'[init] lldacing patched: {f}')
PYEOF

echo "[init] DONE"
EOF
RUN chmod +x /opt/init-pulid.sh

# 원본 start.sh를 wrapper로 감쌈
RUN mv /start.sh /start-original.sh \
 && cat > /start.sh <<'EOF'
#!/bin/bash
/opt/init-pulid.sh
exec /start-original.sh "$@"
EOF
RUN chmod +x /start.sh

RUN echo "comfyui-pulid-v2: zhangp365 191cd99775 + 4 kwargs patches + pip deps + entrypoint copy" > /etc/image-stack.txt

CMD ["/start.sh"]
