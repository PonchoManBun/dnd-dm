# Jetson Orin Nano Setup: LLM + Godot 4 on 8GB

## Hardware Specs

| Spec | Detail |
|------|--------|
| GPU | NVIDIA Ampere, 1024 CUDA cores, compute capability 8.7 |
| CPU | 6-core ARM Cortex-A78AE |
| Memory | 8 GB LPDDR5 shared CPU/GPU, 68 GB/s bandwidth |
| Storage | NVMe M.2 SSD slot |
| AI Performance | 67 TOPS (Super mode) / 40 TOPS (original) |
| Power | 7W / 15W / 25W modes |
| Software | JetPack 6.2 (L4T 36.4.3), CUDA 12.6, cuDNN 9.3 |

**Super Mode:** Free firmware update (JetPack 6.2) that unlocks up to 70% more AI performance.

---

## 1. LLM Models That Fit in 8GB

### Official NVIDIA Benchmarks (INT4 via MLC API)

| Model | Params | Orin Nano (tok/s) | Orin Nano Super (tok/s) |
|-------|--------|-------------------|-------------------------|
| SmolLM2 1.7B | 1.7B | 41 | 64.5 |
| Gemma 2 2B | 2B | 21.5 | 35.0 |
| Llama 3.2 3B | 3B | 27.7 | 43.1 |
| Phi 3.5 Mini | 3.8B | 24.7 | 38.1 |
| Qwen2.5 7B | 7B | 14.2 | 21.8 |
| Llama 3.1 8B | 8B | 14.0 | 19.1 |
| Gemma 2 9B | 9B | 7.2 | 9.2 |

### Independent Benchmarks (Ollama, various sources)

| Model | Params | ~tok/s (25W) | Q4_K_M Size |
|-------|--------|-------------|-------------|
| Qwen2.5 0.5B | 0.5B | ~47 | ~0.4 GB |
| TinyLlama | 1.1B | ~40 | ~0.7 GB |
| Llama 3.2 1B | 1B | ~38 | ~0.6 GB |
| Gemma2 2B | 2B | ~25 | ~1.5 GB |
| **Llama 3.2 3B** | 3B | ~22-43 | **~2.0 GB** |
| **Qwen2.5 3B** | 3B | ~22-43 | **~1.8 GB** |
| **Phi-3.5 Mini** | 3.8B | ~20-38 | **~2.2 GB** |
| Qwen2.5 7B | 7B | ~14-22 | ~4.5 GB |
| Mistral 7B | 7B | ~8-14 | ~4.1 GB |

### Recommendation

**Stick with 3B-class models at Q4_K_M quantization.** Specifically:
- **Llama 3.2 3B** -- best general-purpose, good tool calling support
- **Qwen2.5 3B** -- strong reasoning for its size
- **Phi-3.5 Mini (3.8B)** -- strong reasoning, slightly larger

These use ~2GB for weights, leave room for Godot/OS, and deliver 20-43 tok/s -- fast enough for DM text generation.

**7B models are risky** -- they consume 4+ GB, leaving almost no room for Godot and OS. Not recommended for simultaneous operation.

---

## 2. Ollama on Jetson

### Does It Work?

**Yes, with caveats.**

### Installation

**Method 1 -- Native (simplest):**
```bash
curl -fsSL https://ollama.com/install.sh | sh
```

**Method 2 -- Docker via jetson-containers (most reliable):**
```bash
git clone https://github.com/dusty-nv/jetson-containers.git
cd jetson-containers
sudo bash install.sh
jetson-containers run $(autotag ollama)
```

### Known Issues

- **GPU driver regression in Ollama 0.5.8+:** `cudaSetDevice err: 35`, models fall to CPU. Tracked in ollama/ollama#9503.
- **Workarounds:** Pin to Ollama 0.5.7, or use Docker/jetson-containers. Ensure `/usr/local/cuda/lib64` in `LD_LIBRARY_PATH`.
- **Performance mode:** Always run `sudo nvpmodel -m 0` and `sudo jetson_clocks`.

### Alternative Inference Engines

| Engine | Pros | Cons |
|--------|------|------|
| **llama.cpp** | Lightweight, CUDA on Jetson, GGUF, active community | Manual setup |
| **TensorRT-LLM** | Best performance on Jetson, NVIDIA-optimized | Harder to set up, build from source |
| **MLC LLM** | Used in NVIDIA official benchmarks | Smaller community |

**Recommendation:** Start with Ollama via Docker/jetson-containers. Fall back to llama.cpp if GPU issues persist.

---

## 3. Godot 4 on Jetson (ARM64 Linux)

### Official Support

**Yes -- Godot 4 has official ARM64 Linux builds** since Godot 4.2. Available at godotengine.org/download/linux/ for:
- x86_64, x86_32, **arm64**, arm32

Current stable: **Godot 4.5.1** with ARM64 builds.

### 2D Performance

- Godot 4's 2D engine is lightweight and separate from 3D
- 1024 CUDA cores is massive overkill for 2D pixel art
- Use OpenGL/Compatibility renderer (less memory than Vulkan)
- Memory footprint: ~150-400 MB for a simple 2D game
- Pixel art textures are tiny (256x256 sheet = 256KB)

### Potential Issues

- **Vulkan driver:** L4T includes Vulkan drivers; OpenGL Compatibility is a safe fallback
- **Build from source:** If official ARM64 binary has L4T issues, community [Godot_ARMory](https://github.com/zhangxuelei86/Godot_ARMory) provides build scripts
- No known Jetson-specific showstoppers for 2D games

---

## 4. Memory Budget

| Component | RAM Usage | Notes |
|-----------|----------|-------|
| L4T / Ubuntu OS (headless) | ~800 MB | Desktop GUI disabled saves ~800 MB |
| System reserved | ~500 MB | Kernel, firmware, GPU driver |
| Ollama overhead | ~200-300 MB | Runtime beyond model weights |
| 3B LLM (Q4_K_M) | ~2.0 GB | Llama 3.2 3B or Qwen2.5 3B |
| KV cache (context) | ~200-500 MB | 2048 tokens is modest |
| Godot 4 (2D pixel art) | ~200-400 MB | Pixel art assets are lightweight |
| Python DM orchestrator | ~50-100 MB | Python runtime + orchestration |
| **TOTAL** | **~4.0-4.6 GB** | |
| **Remaining** | **~1.9-2.5 GB** | Buffer for caches, spikes |

### Verdict: YES, it fits -- but it's tight.

With a 3B model, headless OS, and simple 2D Godot game, you use ~4-4.6 GB of ~6.5 GB usable, leaving ~2 GB headroom.

**7B model would push to ~6.5-7 GB -- not recommended** for simultaneous operation with Godot.

### Swap Configuration

Default JetPack ships with ~3.7 GB zram swap. Zram performs poorly for LLM workloads.

**Recommended: NVMe SSD swap instead:**
```bash
sudo systemctl disable nvzramconfig
sudo fallocate -l 8G /mnt/nvme/swapfile
sudo chmod 600 /mnt/nvme/swapfile
sudo mkswap /mnt/nvme/swapfile
sudo swapon /mnt/nvme/swapfile
```

---

## 5. Optimization Tips

1. **Run headless** -- disable Ubuntu desktop GUI to save ~800 MB
2. **Use Compatibility (OpenGL) renderer** in Godot
3. **Keep context length short** -- 2048 tokens, not 4096+
4. **Stick with 3B models** -- 7B is dangerously tight
5. **Performance mode:** `sudo nvpmodel -m 0` and `sudo jetson_clocks`
6. **NVMe swap** as safety net (8 GB file on SSD)
7. **Super Mode firmware** -- free JetPack 6.2 update for up to 70% more AI perf

---

## 6. Development Workflow

TWW uses a **two-machine workflow**: develop on Windows 11 laptop, deploy and play on Jetson. See `specs/research/dev-workflow.md` for full details on SSH, git, rsync, VS Code Remote-SSH, and Godot ARM64 export.
