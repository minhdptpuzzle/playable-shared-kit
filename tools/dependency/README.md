# Portable Dependency Runtimes (`tools/dependency/`)

Thư mục này chứa sẵn các bộ runtime portable / standalone runnable để toàn bộ tool trong `playable-shared-kit` (Audio Optimizer, MCP servers, Blender tools, Porting scripts...) có thể chạy trực tiếp offline trên bất kỳ máy nào mà không yêu cầu cài đặt thủ công.

## Cấu trúc thư mục

```
tools/dependency/
├── ffmpeg/
│   ├── bin/ffmpeg.exe
│   └── ffmpeg.exe         # Portable FFmpeg binary cho Audio Optimizer
├── python/
│   ├── python.exe         # Portable Python 3.11 standalone runtime
│   ├── python311.dll
│   └── python311.zip
└── uv/
    └── uv.exe             # Standalone uv tool runner cho Python venvs / MCPs
```

## Tự động kiểm tra & Cài đặt

- **Kiểm tra trạng thái các dependency**:
  ```bash
  npm run dependencies:scan
  ```

- **Tự động tải và thiết lập toàn bộ bộ runnable portable khi sang máy mới**:
  ```bash
  npm run dependencies:setup
  # hoặc: node playable-shared-kit/tools/ensure-dependencies.cjs --download-all
  ```
