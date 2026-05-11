FROM runpod/comfyui:latest                                                                                                        
                                                                                                                                    
  RUN mkdir -p /opt/pulid-bundle && cd /opt/pulid-bundle && git clone https://github.com/zhangp365/ComfyUI-PuLID-Flux.git && cd     
  ComfyUI-PuLID-Flux && git checkout 191cd99775                                                                                     
                                                                                                                                    
  RUN python3 -c "p='/opt/pulid-bundle/ComfyUI-PuLID-Flux/pulidflux.py'; src=open(p).read(); old='attn_mask: Tensor = None,\n    )  
  -> Tensor:'; new='attn_mask: Tensor = None,\n        **kwargs,\n    ) -> Tensor:'; src = src.replace(old, new, 1) if old in src 
  else src; open(p,'w').write(src); print('patch1 done')"                                                                           
                                                         
  RUN pip install --no-cache-dir facexlib insightface onnxruntime onnxruntime-gpu ftfy timm                                         
  
  RUN printf '#!/bin/bash\nset -e\nDEST=/workspace/runpod-slim/ComfyUI/custom_nodes/ComfyUI-PuLID-Flux\nif [ ! -f                   
  "$DEST/pulidflux.py" ]; then\n  cp -r /opt/pulid-bundle/ComfyUI-PuLID-Flux "$DEST"\n  echo "[init] PuLID copied"\nfi\necho "[init]
   DONE"\n' > /opt/init-pulid.sh && chmod +x /opt/init-pulid.sh                                                                     
                                                         
  RUN mv /start.sh /start-original.sh && printf '#!/bin/bash\n/start-original.sh "$@" &\nORIG_PID=$!\necho "[wrapper] wait for      
  ComfyUI deploy..."\nfor i in $(seq 1 60); do\n  [ -f /workspace/runpod-slim/ComfyUI/main.py ] && break\n  sleep 2\ndone\nif [ ! -f
   /workspace/runpod-slim/ComfyUI/main.py ]; then\n  echo "[wrapper] ERROR: ComfyUI not deployed"\n  wait $ORIG_PID\n  exit         
  1\nfi\n/opt/init-pulid.sh\necho "[wrapper] wait initial ComfyUI..."\nfor i in $(seq 1 60); do\n  curl -s -m 2 
  http://localhost:8188/system_stats >/dev/null 2>&1 && break\n  sleep 2\ndone\necho "[wrapper] restart ComfyUI to load           
  PuLID..."\npkill -f "python main.py" 2>/dev/null || true\nsleep 3\ncd /workspace/runpod-slim/ComfyUI\nsource
  .venv-cu128/bin/activate\npython main.py --listen 0.0.0.0 --port 8188 --enable-cors-header --lowvram --disable-smart-memory\n' >
  /start.sh && chmod +x /start.sh

  RUN echo "comfyui-pulid-v3: race-fixed wrapper" > /etc/image-stack.txt                                                            
  
  CMD ["/start.sh"]    
