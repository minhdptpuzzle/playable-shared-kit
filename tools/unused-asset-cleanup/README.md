# Công cụ dọn asset không dùng

`unused-asset-cleanup` quét dependency graph theo UUID của Cocos Creator để tìm
các asset trong toàn bộ thư mục `assets` không được dùng bởi scene runtime,
source code hoặc dynamic loading.

> Tool này gộp từ `unused-prefab-cleanup.cjs` và wrapper `unused-asset-cleanup.cjs`
> cũ. Wrapper chỉ gọi lại `--scope all`, vốn đã là mặc định, nên đã bị bỏ. Lệnh
> `unused-prefab-cleanup.cjs` tương đương `unused-asset-cleanup.cjs --scope prefabs`.

Tool mặc định chỉ audit và in danh sách. Chỉ khi truyền `--delete`, tool mới xóa:

- Asset không reachable từ runtime roots.
- File `.meta` tương ứng.
- File `.meta` mồ côi khi owner asset hoặc thư mục không còn tồn tại.
- Dependency/reference chỉ thuộc nhóm asset không dùng, ví dụ prefab, FBX,
  material, effect, sprite, texture, sound, animation hoặc JSON.
- Thư mục rỗng và `.meta` của thư mục đó.

Tool không xóa dependency nếu vẫn còn prefab hoặc asset giữ lại reference đến nó.
Sau khi xóa, tool kiểm tra lại dependency graph và fail nếu UUID của asset đã xóa
vẫn còn xuất hiện trong file giữ lại.

## Chạy audit

Chạy từ thư mục gốc của Cocos project:

```powershell
node playable-shared-kit/tools/unused-asset-cleanup.cjs
```

Mặc định tool dùng:

- Phạm vi cleanup: toàn bộ file asset trong `assets`.
- Runtime roots: toàn bộ scene, file `.ts`, file `.js`, `--root` thủ công và
  dynamic asset path phát hiện được.
- Asset UUID được reference từ `settings`, `profiles`, config hoặc `.vscode`
  cũng được giữ lại.
- Source `.ts` và `.js` luôn được giữ lại để tránh xóa nhầm script được import
  hoặc gọi gián tiếp.
- Các đường dẫn literal dạng `resources.load("...", Prefab|JsonAsset, ...)`
  và asset path literal có thư mục được phát hiện tự động trong file `.ts` và
  `.js`. Cách này hỗ trợ cả wrapper loader nhận path qua tham số.
- Template literal có nội suy được resolve theo hằng chuỗi khai báo trong cùng
  file. Ví dụ `const DIR = 'sound/'` cộng với `` `${DIR}sound_click` `` sẽ ra
  đúng `sound/sound_click`. Nếu không resolve được, tool fallback sang so khớp
  theo tên file để tránh xóa nhầm.

## Asset bundle

Thư mục có `userData.isBundle: true` trong `.meta` (gồm cả `assets/resources`)
được Cocos đóng gói nguyên vẹn để load động theo path lúc runtime. Phân tích UUID
tĩnh về nguyên tắc không thể chứng minh các asset này không dùng.

Vì vậy mặc định tool coi **mọi file trong bundle là runtime root**: không bao giờ
liệt kê chúng vào danh sách xóa, và dependency của chúng cũng được giữ.

Báo cáo vẫn cho biết có bao nhiêu asset chỉ sống nhờ luật này. Muốn audit luôn cả
bên trong bundle thì thêm `--include-bundles`:

```powershell
node playable-shared-kit/tools/unused-asset-cleanup.cjs --include-bundles
```

Danh sách in ra ở chế độ này là **ứng viên cần review tay**, không phải kết luận.
Chỉ xóa khi đã tự xác nhận không có code nào load path đó.

## Đưa dependency ra khỏi bundle

Trong bundle chỉ nên có asset thật sự được load động theo path. Dependency kéo
theo bằng UUID không cần nằm đó: chúng làm phình `config.json` của bundle và làm
rối cấu trúc. Tool phân loại asset trong bundle thành ba nhóm:

- **entry point** — có path literal tương ứng trong code, khai bằng `--root`, hoặc
  có UUID xuất hiện trực tiếp trong file `.ts`/`.js`. Không bao giờ bị move.

  Trường hợp UUID hardcode rất dễ bỏ sót: builder của Cocos không đọc code, nên
  asset chỉ được gọi qua `assetManager.loadAny('<uuid>')` sẽ **không được đóng
  gói** nếu nó rời khỏi bundle. Về mặt dependency graph nó trông như dependency
  bình thường, nhưng move ra ngoài là vỡ runtime.
- **dependency-only** — không phải entry, nhưng được asset khác reference qua
  UUID. Đây là nhóm nên chuyển ra ngoài.
- **neither** — không thuộc hai nhóm trên. Tool chỉ liệt kê để review tay, không
  tự xử lý, vì đây có thể là asset load qua path mà tool không suy ra được.

Xem trước kế hoạch chuyển:

```powershell
node playable-shared-kit/tools/unused-asset-cleanup.cjs --move-bundle-deps
```

Thực hiện:

```powershell
node playable-shared-kit/tools/unused-asset-cleanup.cjs --move-bundle-deps --apply
```

Đích đến chọn theo đuôi file, ưu tiên thư mục **đã có sẵn** trong `assets` (khớp
cả dạng số ít/số nhiều, ví dụ `texture` hay `textures`), không có thì tạo mới:

| Đuôi file | Thư mục |
| --- | --- |
| `.png .jpg .jpeg .webp .bmp .tga .psd .tif .tiff` | `textures` |
| `.mtl .pmtl` | `materials` |
| `.effect` | `effects` |
| `.fbx .gltf .glb .obj .dae` | `models` |
| `.anim .animgraph` | `animations` |
| `.prefab` | `prefabs` |
| `.mp3 .ogg .wav .m4a .aac` | `sounds` |
| `.ttf .otf .fnt .bmfont` | `fonts` |
| `.skel .atlas` | `spine` |
| `.json .txt .bin .plist` | `data` |

Đổi thư mục gốc bằng `--deps-dir <path>`. Đuôi file không nằm trong bảng thì
được giữ nguyên tại chỗ và báo ở mục `Left in place`.

**Vì sao move an toàn:** Cocos reference asset theo UUID nằm trong `.meta`, không
theo đường dẫn. Tool move file kèm `.meta` nên UUID không đổi và mọi reference
giữ nguyên. Trùng tên ở đích thì tool tự thêm hậu tố `_1`, `_2` và đánh dấu
`[renamed]`. Sau khi move, tool audit lại và fail nếu số asset unused tăng lên.

Không chạy chung `--delete` với `--move-bundle-deps` trong một lệnh; tool chặn để
mỗi thao tác được review riêng.

Xuất báo cáo JSON đầy đủ:

```powershell
node playable-shared-kit/tools/unused-asset-cleanup.cjs --json
```

## Xóa asset đã xác nhận

Luôn chạy audit và review danh sách trước. Sau đó mới chạy:

```powershell
node playable-shared-kit/tools/unused-asset-cleanup.cjs --delete
```

Sau khi xóa, tool tự quét lại dependency graph. Lệnh trả lỗi nếu vẫn còn prefab
hoặc asset không dùng, phát hiện deletion không an toàn, hoặc còn dangling UUID.

## Chỉ dọn prefab

Để dùng hành vi cũ, chỉ tìm prefab không dùng và dependency riêng của chúng:

```powershell
node playable-shared-kit/tools/unused-asset-cleanup.cjs --scope prefabs
node playable-shared-kit/tools/unused-asset-cleanup.cjs --scope prefabs --delete
```

## Runtime root bổ sung

Khi project load asset bằng biến, chuỗi ghép hoặc custom loader, tool không thể
suy ra đường dẫn tĩnh. Khai báo asset đó bằng `--root`:

```powershell
node playable-shared-kit/tools/unused-asset-cleanup.cjs `
  --root assets/prefabs/power_text/PowerText.prefab `
  --root assets/json/Level23.json
```

Có thể truyền nhiều `--root`.

## Scene và thư mục prefab tùy chỉnh

```powershell
node playable-shared-kit/tools/unused-asset-cleanup.cjs `
  --scene assets/scene/Gameplay.scene `
  --scene assets/scene/Boot.scene `
  --prefab-dir assets/prefabs
```

Có thể truyền nhiều `--scene`. Nếu có ít nhất một `--scene`, tool không tự thêm
toàn bộ scene trong `assets`.

## Tùy chọn

- `--project-root <path>`: chỉ định Cocos project root thay vì tự tìm từ `cwd`.
- `--scope <all|prefabs>`: dọn toàn bộ asset hoặc chỉ prefab. Mặc định là `all`.
- `--prefab-dir <path>`: thư mục prefab cần audit.
- `--scene <path>`: scene runtime root, có thể lặp lại.
- `--root <path>`: asset runtime root bổ sung, có thể lặp lại.
- `--include-bundles`: audit cả asset nằm trong asset bundle. Mặc định tắt.
- `--move-bundle-deps`: xem kế hoạch chuyển dependency ra khỏi bundle.
- `--apply`: thực hiện kế hoạch của `--move-bundle-deps`.
- `--deps-dir <path>`: thư mục gốc cho asset được chuyển ra. Default: `assets`.
- `--json`: in báo cáo JSON đầy đủ.
- `--delete`: xóa asset sau khi kiểm tra reverse reference.
- `--help`: xem hướng dẫn CLI.

## Giới hạn và lưu ý

- Tool dựa trên UUID trong asset serialization và `.meta`.
- Dynamic loading chỉ tự phát hiện được khi code còn chứa literal asset path.
- Với bundle loader, custom loader, đường dẫn ghép hoặc asset được dùng bởi code
  native/plugin, cần khai báo `--root` thủ công.
- Nên commit hoặc backup project trước khi chạy `--delete`.
- Sau khi xóa, mở project bằng Cocos Creator để Editor reimport và chạy gameplay
  smoke test.
