# Thuyết trình SYSDBG — bản đọc

**Người viết:** Nghĩa VT · **Ngày:** 15/09/2026

## Dùng file này thế nào

**Phần I là bài nói**, chín mục, đọc hết khoảng **10 phút**. Nếu bị cắt giờ thì bỏ
mục 6 — nhưng vẫn nên **nhớ** nội dung mục đó, vì ba flow trong đó là thứ thầy hay
hỏi nhất sau khi nghe halt.

**Phần II không đọc lên.** Đó là chiều sâu để trả lời khi bị cắt ngang.

Thuật ngữ kỹ thuật, tên tín hiệu, tên thanh ghi giữ nguyên tiếng Anh.

## Slide

Mọi hình dưới đây **lấy nguyên từ tài liệu SYSDBG**, không dùng hình riêng cho
slide. Lý do: hình riêng sẽ lệch khỏi spec — bản cũ của bài này từng dùng một hình
chỉ vẽ **hai** khối, từ hồi em chưa nhận `INTMAP`.

| Hình | File | Là hình nào trong tài liệu | Lúc nào |
|---|---|---|---|
| **A** | `img/fig_dbg_simple.png` | **Figure 2** — The SYSDBG block | Phần 2 tới 4 |
| **B** | `img/fig_sysdbg_internal.png` | **Figure 3** — Internal structure, and the two clock domains | Phần 4 |
| **C** | `img/fig_jtag_cmd.png` | **Figure 4** — The ACCESS register, bit by bit | Khi nói thanh ghi 68 bit |
| **D** | `img/fig_halt_flow.png` | **Figure 6** — Halting the CPU, end to end | Phần 5, chín bước |
| **E** | `img/fig_sysdbg_fsm.png` | **Figure 5** — Command FSM | Chỉ khi bị hỏi về FSM |
| **F** | `img/fig_sysdbg_ports.png` | **Figure 7** — What one bus port can and cannot reach | Phần 7, khi nói một cổng với tới được gì |
| **G** | `img/fig_host_stack.png` | **Figure 8** — Host software stack | Chỉ khi bị hỏi về phía PC |

Nếu chỉ được hai hình thì lấy **A** và **D**: một cái cho thấy khối là gì, một cái
cho thấy một lệnh đi hết vòng. Năm hình còn lại để trả lời câu hỏi.

Tài liệu SYSDBG có **8 Figure**; bài này dùng 7. Cái không dùng là Figure 1, vì nó
là hình toàn chip và phần mở đầu chung đã có `fig_qsoc_full.png` rồi.

Phần trong ngoặc vuông là chỉ dẫn, không đọc.

# PHẦN I — BÀI NÓI

## 1. Mở đầu

*[Hình A. Nói hai câu rồi đi tiếp.]*

Em chào thầy và các bạn. Đây là **SYSDBG**, khối debug của QSOC — và là khối **duy
nhất trong ba khối của em không dùng IP nào**. `RAM` và `INTMAP` là tích hợp; khối
này em viết từ đầu, nên mọi thứ trong đó em nói được **vì sao em chọn như vậy**.

## 2. Khối này để làm gì, nói trong một câu

SYSDBG nhận một kết nối **JTAG** từ PC của em, biến các lệnh đến trên đó thành
**bus transaction** trên system bus, lái đúng một sợi dây đi vào CPU tên là
**`debug_req`**, và báo status ngược về.

Bốn động từ: **kết thúc JTAG, phát ra bus, lái `debug_req`, báo về.**

Nó treo vào `AXI_S0` làm **master**, nên với tới mọi thứ trên bus; và nó có một sợi
dây riêng vào CPU, sợi dây đó không thuộc bus nào.

## 3. Câu hỏi em phải trả lời đầu tiên

CPU Ibex chỉ có **đúng một** chân input cho debug, tên là `debug_req_i`. Một sợi
dây. Đó là toàn bộ giao diện debug của core.

Vậy: **làm sao debug được một con CPU khi thứ duy nhất mình làm được với nó là
kéo một sợi dây lên mức 1?**

Câu trả lời là sợi dây đó chỉ là **cái kích hoạt**. Thứ biến nó thành debugger là
mọi thứ mình xây quanh nó — và đó chính là khối em đang thiết kế.

Khi `debug_req` lên mức 1, core làm bốn việc trong một chu kỳ:

1. lưu địa chỉ lệnh sắp chạy vào một CSR tên là **`dpc`**,
2. ghi **`dcsr.cause = 3`** — "debugger yêu cầu tôi dừng",
3. nhảy tới một địa chỉ cố định, **`DmHaltAddr`**,
4. vào **Debug Mode**, ở đó interrupt bị che và lệnh `DRET` trở thành hợp lệ.

Hai chi tiết chi phối thiết kế của em. Tín hiệu là **level-sensitive**, nên một
xung ngắn có thể bị bỏ lỡ hoàn toàn — phải **giữ** nó ở mức cao. Và core **không
có output nào** báo cho em biết nó đã dừng.

## 4. Bên trong khối phải có gì

*[Bật Hình B. Để nguyên tới hết bài.]*

Năm mảnh, và khi đã biết ở trên thì chúng gần như tự hiện ra:

- một **JTAG front-end**, vì chuẩn đã quy định TAP controller phải như thế nào;
- một **clock domain crossing**, vì `TCK` do board adapter trên bàn em phát ra,
  không liên quan gì tới clock của chip, và **dừng hẳn** giữa hai lệnh;
- một **command FSM** và một **register file** nhỏ, quyết định mỗi lệnh nghĩa là
  gì;
- một **bus master** kiểu `req` / `gnt` / `rsp_valid` kèm byte enable, để với
  tới toàn bộ memory map;
- và bản thân phần **logic lái `debug_req`**.

Giờ em xin cho thấy chúng chạy như thế nào.

## 5. Một lệnh, đi hết một vòng

Halt CPU là ví dụ đầy đủ ngắn nhất, và nó chạm vào đủ cả năm mảnh.

**1 — chương trình của em gọi `halt()`.** Bên dưới nó chỉ là
`write(0xF000_0000, 1)`. Mọi thứ debugger này làm được đều quy về một lệnh đọc
hoặc một lệnh ghi tại một địa chỉ.

**2 — lời gọi đó thành một lần scan JTAG.** Em thiết kế thanh ghi lệnh thành
**một thanh ghi 68 bit**: hai bit opcode, **hai bit `size`**, ba mươi hai bit địa
chỉ, ba mươi hai bit dữ liệu. Một lần scan là một thao tác. Hai bit `size` là để
ghi được **byte và halfword**, không chỉ word — QSOC là RV32I**MC**, nên đặt một
software breakpoint lên lệnh compressed là một lần ghi **halfword**.

**3 — lệnh băng qua sang clock của chip.** Tại **Update-DR**, là thời điểm JTAG
quy định nghĩa "những bit này đã chốt", cả 68 bit được chốt một lượt. Rồi chỉ
**hai sợi dây** băng qua ranh giới clock — một request và một acknowledge — vì
sau Update-DR thì `TCK` có thể dừng hẳn.

**4 — FSM giải mã.** Nó nhìn bốn bit cao của địa chỉ. `0xF` là thanh ghi nội bộ
của SYSDBG; còn lại đẩy thẳng cho bus master. Lệnh này là local, nên nó ghi
`CTRL[0] = 1`.

**5 — `debug_req` lên mức 1 và ở nguyên đó.** Không phải một xung. Nó giữ nguyên
cho tới khi phần mềm của em yêu cầu resume.

**6 — CPU phản ứng.** `dpc`, `dcsr.cause = 3`, nhảy tới `DmHaltAddr`, vào Debug
Mode.

**7 — SYSDBG biết là core đã dừng.** Core báo cho em qua một sợi dây tên là
`debug_mode`, và `STATUS[2]` lên 1. Lát nữa em quay lại sợi dây này.

**8 — câu trả lời đi ngược ra.** Tại **Capture-DR**, kết quả được nạp vào sẵn
sàng đi ra, rồi dịch ra `TDO` trong lần scan kế tiếp.

**9 — chương trình của em thấy được.** Nó đọc `STATUS`, xét bit 2, và biết CPU đã
dừng.

*[Dừng một nhịp.]*

Đọc một ô nhớ là **đúng vòng đó** — khác duy nhất ở bước 4, opcode là READ và địa
chỉ không phải `0xF`, nên nó đi sang AXI master. Resume cũng là vòng đó với
`CTRL[1]`. Nạp firmware là vài nghìn lệnh ghi.

Thật ra trong khối này chỉ có đúng một đường đi, và em dựng nó một lần.

## 5b. Toàn bộ luồng debug, từ đầu đến cuối — ai làm gì

*[Vẫn Hình D. Đây là phần thầy hỏi nhiều nhất, nói chậm.]*

Mục 5 kể **một lệnh** đi hết vòng. Mục này kể **cả phiên debug**: từ lúc bắt CPU
dừng, soi xong, tới lúc cho chạy lại. Em nói rõ **mỗi bước ai làm**.

**Dừng CPU.**

1. **Host** (qua JTAG): ghi `haltreq` vào `CTRL`.
2. **SYSDBG**: kéo `debug_req_o` lên 1 và **giữ mức**.
3. **CPU**: chạy nốt lệnh đang làm, vào Debug Mode — lưu PC vào `dpc`, lý do vào
   `dcsr`, rồi **nhảy tới `DmHaltAddr = 0x2000_0800`**.
4. **Host**: đọc `STATUS`, thấy `cpu_halted` — biết đã dừng.

**CPU chờ trong một vòng lặp.**

5. **CPU**: tại `0x2000_0800` có sẵn một **dispatch loop** — do `SYSDBG` nạp vào
   cửa sổ debug từ trước. CPU chạy vòng lặp này, cứ quay tròn hỏi hai ô nhớ:
   *command word* (`0x2000_0F08`, có việc không?) và *resume flag* (`0x2000_0F0C`,
   chạy tiếp chưa?). CPU giờ bị "giam" ở đây, chờ lệnh.

*[Note — hai ô đó là gì, nếu bị hỏi.] Cả hai chỉ là **ô nhớ thường trong ISRAM**
(không phải phần cứng, chỉ là quy ước địa chỉ). **Command word**: `SYSDBG` đặt ≠ 0
để báo "có chuỗi lệnh sẵn ở `0x2000_0000`", **CPU** xoá về 0 khi chạy xong.
**Resume flag**: `SYSDBG` đặt ≠ 0 khi host resume, **dispatch loop** xoá rồi chạy
`DRET`. `SYSDBG` ghi qua **master port**; `CPU` đọc/xoá bằng **fetch & execute** —
nên không thêm cổng phần cứng nào.*

**Soi dữ liệu.**

6. Đọc/ghi **RAM, ROM, ngoại vi**: **SYSDBG tự làm**, đi master port → `AXI_S0`
   → `S_BUS`, không phiền CPU.
7. Đọc **thanh ghi trong CPU**: **SYSDBG** ghi một chuỗi lệnh vào cửa sổ, để
   **CPU tự chạy** (dùng `dscratch0/1` cất tạm), kết quả ghi ra window rồi
   `SYSDBG` đọc lại. Không thêm cổng nào.

**Cho CPU chạy lại — thứ tự bắt buộc.**

8. **Host** (ghi thứ nhất): `resumereq` vào `CTRL[1]` → xoá `haltreq` →
   **`debug_req_o` xuống thấp**.
9. **Host** (ghi thứ hai, sau bước 8): ghi giá trị khác 0 vào **resume flag**
   `0x2000_0F0C` — một lệnh ghi bộ nhớ qua master port, scan JTAG riêng.
10. **CPU** (dispatch loop): thấy resume flag → xoá flag → chạy lệnh **`DRET`** →
    khôi phục `dpc`, rời Debug Mode, **chạy tiếp** từ chỗ đã dừng.

**Chỗ mấu chốt — thầy chắc chắn hỏi:** hạ `debug_req` **không** làm CPU chạy lại.
Đọc `ibex_controller.sv`, core chỉ rời Debug Mode ở **đúng một chỗ: nhánh `DRET`**.
Mà CPU đang chạy dispatch loop, nên **loop phải chạy `DRET`** — đó là lý do phải có
resume flag để "gọi" nó. Nếu bật resume flag khi `debug_req` còn cao, core `DRET`
xong sẽ **halt lại ngay lệnh kế** — nhìn từ host như resume bị lờ đi. Vì vậy resume là **hai lệnh ghi của host, không đổi thứ tự được**: hạ `debug_req`
trước, rồi mới bật resume flag.

## 6. Ba flow còn lại, mỗi cái vài dòng

Halt là flow dài nhất. Ba cái còn lại ngắn hơn nhiều, nhưng nên nói vì cùng nhau
chúng là **toàn bộ** những gì khối này làm.

**Resume — không chỉ hạ `debug_req`.** Host ghi `resumereq` vào `CTRL`. Việc này
làm hai điều cùng lúc: **hạ `debug_req` xuống** và **bật resume flag** trong cửa
sổ. Dispatch loop thấy flag → chạy **`DRET`** → core mới thật sự rời Debug Mode.
`haltreq` thì **giữ mức** (không tự xoá, vì `debug_req` level-sensitive); còn
`resumereq` **tự xoá**, vì nó là một **sự kiện**. Điểm phải nhớ: hạ `debug_req`
một mình **không** đủ — chỉ `DRET` mới thoát Debug Mode (mục 5b).

**Đọc một địa chỉ — luôn hai lần scan.** Scan 1 gửi `op = READ` với địa chỉ; scan 2
gửi `NOP` và **thu kết quả của scan 1**. Không phải thiết kế kém: trong scan chain,
bit dịch **vào** và dịch **ra** xảy ra **cùng lúc**, nên lúc đang dịch ra thì lệnh
mới còn chưa chạy. Thanh ghi DMI của `riscv-dbg` cũng đúng hình dạng đó.

**Nạp firmware — N lần write rồi thả core.** Ghi ảnh vào `ISRAM` bằng một loạt
`write`, mỗi cái một scan; rồi ghi `resumereq`. Đây là đường **thứ hai** để nạp
chương trình — đường chính là bootloader qua UART, còn đường này dùng khi chính ROM
đáng nghi.

## 7. Làm được gì, và không làm được gì

Khối này halt được CPU, resume, reset, **đọc ghi mọi địa chỉ trong memory map kể cả
khi CPU đang chạy**, nạp firmware và cho chạy. Và nó **đọc được thanh ghi CPU** — cả
`x5` lẫn `dpc`.

Cái cuối cùng đó đáng nói riêng, vì nó là thứ **trông như phải thêm phần cứng mà
không cần**.

Thanh ghi CPU **không có địa chỉ trên bus**, nên bus master không với tới được. Cách
duy nhất được định nghĩa là **bắt chính core thực thi một lệnh store**, rồi mình đọc
chỗ nó vừa ghi. Mà core thực thi thì phải fetch — tức phải có một vùng bộ nhớ core
đọc được.

**Và vùng đó đã có sẵn: 4 KiB đầu của `ISRAM`**, theo đúng chỉ đạo của thầy. `ISRAM`
vốn đã là slave trên `AXI_M1`, nên core fetch được. Còn chuỗi lệnh thì `SYSDBG` ghi
vào đó **bằng chính master port nó đang có**.

Nên **không cổng nào được thêm ở đâu cả** — không trên `SYSDBG`, không trên `S_BUS`.
Một debug module chuẩn thì đặt **Program Buffer bên trong nó** và cho core fetch từ
đó, mà như vậy là **buộc khối debug phải thành slave**. Em không làm thế, nên khối
này chỉ có **một cổng bus duy nhất, và nó là master**. Sơ đồ khối như thầy vẽ **không
phải sửa**.

**Giới hạn thật thì chỉ có một, và em xin nói thẳng:** đọc thanh ghi **buộc phải halt
core**, vì cơ chế này vay chính pipeline của core. Đọc bộ nhớ thì không cần halt;
đọc thanh ghi thì luôn cần.

## 8. Những gì em cần từ người khác

**Xin bạn Sinh, phía CPU:** bạn xuất `debug_mode` ra được không? Dùng giá trị nào
cho `DmHaltAddr` và `DmExceptionAddr`. Giá trị em đề nghị là **`0x2000_0800`** và
**`0x2000_0810`** — suy ra từ memory map, tức base `0x2000_0000` cộng offset của
`dm_pkg`, **không** được để mặc định của Ibex, vì `DmExceptionAddr` mặc định trỏ vào
**resume entry** của `riscv-dbg` chứ không phải exception entry.

**Cũng xin bạn Sinh:** bật **`DbgTriggerEn = 1'b1`** với **`DbgHwBreakNum = 1`**.
Đây là tham số **compile-time** của `ibex_top` nên phải chốt trước khi elaborate,
không sửa được sau bằng phần mềm. Cần vì breakpoint mềm là ghi lệnh `ebreak` vào
chỗ cần dừng, mà **ROM không ghi được** — và ROM chứa bootloader.

**Xin bạn Nam, phía clock và reset:** thả `SYSDBG` ra khỏi reset **trước** core, đó
là halt-on-reset. Và clock gate `D15` bit 14 phải **mặc định mở, software không đóng
được** — nếu đóng được thì đó là một cách vô hiệu hoá debugger trong im lặng.

**Xin thầy:** QSOC dùng
`IDCODE` nào? Và thanh ghi lệnh của em có nên làm tương thích DMI, để sau này dùng
được OpenOCD với GDB mà không phải thiết kế lại?

## 9. Kết

CPU cho em một sợi dây. SYSDBG là khối biến sợi dây đó thành một debugger, bằng
cách kết thúc JTAG, băng qua một clock domain, và chuyển lệnh thành AXI
transaction. Nó cho halt, resume, truy cập toàn bộ bộ nhớ, nạp firmware, và đọc được
thanh ghi CPU — tất cả **không cần debug ROM và không cần slave port**.

Em xin hết, em sẵn sàng nhận câu hỏi ạ.

---

# PHẦN II — KHÔNG ĐỌC LÊN

Toàn bộ bên dưới là cho bạn, không phải cho phòng họp. Đọc trước; dùng khi bị cắt
ngang.

## Phía PC, và thứ tự bring-up

Bốn tầng: `libftdi` ở chế độ MPSSE biến USB thành bốn dây JTAG, một JTAG layer
với `ir_scan` và `dr_scan`, một SYSDBG API gồm `read` / `write` / `halt` /
`resume`, và ứng dụng debug ở trên cùng.

Thứ tự bring-up sắp sao cho mỗi bước chứng minh đúng một thứ:

| Bước | Chứng minh được |
|---|---|
| 1. Đọc `IDCODE` | Chain JTAG và ánh xạ chân |
| 2. Ghi `CTRL`, đọc lại `STATUS` | Thanh ghi lệnh, CDC, FSM |
| 3. Ghi `haltreq`, poll `STATUS[2]` | **`debug_req` tới được CPU và CPU phản ứng** |
| 4. Ghi rồi đọc lại một word trong RAM | AXI master |
| 5. Nạp chương trình, resume, xem nó chạy | Toàn bộ đường đi |

Bước 3 là bài kiểm tra nghiệm thu. Đó là lúc `debug_req` trở thành thứ nhìn thấy
được từ PC.

## Vì sao cần `debug_mode` từ CPU

Ibex không có output nào báo là nó đang ở Debug Mode. Cách chuẩn — cách
`riscv-dbg` làm — là gián tiếp: đặt một **debug ROM** vào memory map, để core đã
dừng chạy nó rồi **ghi** vào một địa chỉ đã biết, và mình rình lệnh ghi đó. Nhưng
rình được một lệnh ghi thì phải có **slave port trên bus**, mà SYSDBG chỉ có
master port.

Rồi em phát hiện tín hiệu đó **đã tồn tại sẵn** bên trong core, là `debug_mode_q`
trong `ibex_controller.sv`. Chỉ là nó chưa được nối ra chân — thậm chí nó đã được
xuất ra cho verification dưới tên `rvfi_ext_debug_mode`.

Nên đề xuất của em là xin bạn Sinh xuất **`debug_mode`** ra khỏi `ibex_top`. Đó
là một thay đổi nhỏ và cục bộ, và chỉ với sợi dây đó thì `STATUS[2]` trở thành
**quan sát trực tiếp** thay vì suy đoán — và nhờ nó mà **không cần debug ROM, cũng
không cần slave port.**

Em nghĩ đây là ví dụ rõ cho khác biệt giữa tích hợp một khối chuẩn và tự thiết kế
khối của mình. Chuẩn phải chạy được với mọi core RISC-V trên đời nên nó không được
phép giả định tín hiệu đó tồn tại. Còn em thiết kế khối này ngay cạnh core, nên em
hỏi một câu là xong.

## Bốn câu thầy gần như chắc sẽ hỏi

Khối này là **self-designed**, nên thầy sẽ không hỏi "IP này là gì" mà hỏi "**vì sao
em làm như thế**". Bốn câu dưới đây là bốn dạng đó, và chúng đáng học kỹ hơn mọi
thứ khác trong file.

### 1. "JTAG của em làm gì?"

Câu trả lời bắt đầu bằng một phân định, vì nó cho thấy em biết ranh giới:

**Em không thiết kế JTAG.** Chuẩn IEEE 1149.1 đã thiết kế JTAG. TAP controller 16
trạng thái, cách `TMS` lái nó, `IDCODE` và `BYPASS` bắt buộc phải có, việc `TDI` lấy
mẫu ở cạnh lên và `TDO` đổi ở cạnh xuống — **không cái nào em chọn được**. Em
implement chúng cho đúng chuẩn.

**Thứ em thiết kế là cái chạy trên nó**: thanh ghi `ACCESS` 68 bit. Đó là chỗ duy
nhất trong phần JTAG mà em có quyền quyết định, và em quyết ba điều — một scan là
một lệnh trọn vẹn, kết quả về ở scan kế tiếp, và có trường `size` để ghi được
halfword.

Nói theo cách khác: **JTAG là cái ống, `ACCESS` là giao thức em đặt trong ống đó.**

### 2. "Ibex chỉ có một sợi dây, sao debug được mọi thứ trong SoC?"

Đây là câu quan trọng nhất, và câu trả lời là **khối có hai đường hoàn toàn tách
nhau, chỉ một đường chạm vào CPU**:

| Đường | Đi qua đâu | Làm được gì | Cần CPU hợp tác? |
|---|---|---|---|
| **Điều khiển chạy** | `debug_req`, một sợi dây vào CPU | dừng, chạy lại, reset | Có — nhưng chỉ để **dừng** |
| **Quan sát** | **bus master** trên `AXI_S0` | đọc ghi **mọi địa chỉ** trong memory map | **Không, hoàn toàn không** |

Chỗ chốt: **mình không debug *qua* CPU, mình debug *quanh* nó.** Debugger là một
**master ngang hàng** trên bus, không phải một tính năng của CPU. Sợi dây kia chỉ
làm đúng một việc — dừng core — và mọi việc còn lại đi đường bus.

Ba hệ quả, và cả ba đều là thứ một sợi dây không làm được:

- **Đọc ghi bộ nhớ khi CPU đang chạy.** Vì đường quan sát không cần CPU đồng ý.
- **Đọc được cả khi CPU đã treo cứng.** Core kẹt trong vòng lặp hay đợi một slave
  không trả lời thì bus master vẫn đi, nên vẫn xem được bộ nhớ để biết vì sao.
- **Xem được bộ nhớ xuyên qua một lần reset hệ thống.** Chip có ba nguồn reset —
  POR, watchdog, software — và `SYSDBG` **không nằm trong** cây reset của software
  reset (nó ở reset domain riêng, chỉ POR mới chạm tới). Nên khi phần còn lại của
  chip bị software reset, host **không mất kết nối JTAG** và halt lại được ngay khi
  core vừa ra khỏi reset.

Và ranh giới trung thực: thứ **duy nhất** không với tới được bằng đường bus là
**thanh ghi của chính CPU**, vì chúng không có địa chỉ trên bus. Đó đúng là ranh
giới thật của khối, và nó được nêu ra chứ không bị giấu.

### 3. "Sao lại có cái này, cái kia?"

Mỗi mảnh tồn tại vì một **ràng buộc bắt buộc**, không vì em thích. Nếu bị hỏi từng
mảnh thì trả lời theo cột phải:

| Mảnh | Ràng buộc bắt buộc nó phải có |
|---|---|
| JTAG front-end | Chuẩn 1149.1. Không chọn được |
| Clock domain crossing | `TCK` do board trên bàn phát, không liên quan clock chip, và **dừng hẳn** giữa hai lệnh |
| `ACCESS` 68 bit | Scan chain không có địa chỉ, nên cả lệnh phải nằm vừa trong một thanh ghi |
| Trường `size` 2 bit | RV32I**MC**: breakpoint trên lệnh compressed là ghi **halfword** |
| Command FSM | Phải phân biệt địa chỉ nội bộ với địa chỉ hệ thống, và phải trả `BUSY` |
| Register file JTAG-only | Firmware chạy trên CPU **không được** tự halt mình hay tự cấp quyền debug |
| Bus master | Là toàn bộ đường quan sát. Không có nó thì chỉ dừng được core mà không xem được gì |
| `debug_req` phải **giữ** | Tín hiệu **level-sensitive** — một xung ngắn có thể bị bỏ lỡ hoàn toàn |
| Xin `debug_mode` từ CPU | Core **không có output** nào báo nó đã dừng |
| `SYSDBG` ở reset domain riêng | Software reset chip mà reset luôn debugger thì mất kết nối đúng lúc cần nhất; chỉ POR mới được chạm tới `SYSDBG` |

Không dòng nào trong bảng đó là sở thích.

### 4. "Flow đi sao?" — bốn flow, không chỉ halt

Phần 5 đã kể **halt** trọn vẹn. Ba flow còn lại, mỗi cái ba dòng:

**Đọc một địa chỉ — luôn là hai scan.** Scan 1 gửi `op = READ` với địa chỉ; scan 2
gửi `NOP` và thu kết quả của scan 1. Lý do đã nói ở phần 6.

**Nạp firmware — N lần write rồi thả core.** Ghi ảnh vào `ISRAM` bằng một loạt
`write`, mỗi cái một scan; rồi ghi `resumereq`. Không cần halt trước nếu core đang
đợi trong ROM. Đây là đường **thứ hai** để nạp chương trình — đường chính là
bootloader qua UART, còn đường này dùng khi chính ROM đáng nghi.

**Resume — không chỉ hạ `debug_req`.** Ghi `resumereq` làm hai việc cùng lúc: hạ
`debug_req` xuống và bật resume flag trong cửa sổ. Dispatch loop thấy flag → chạy
**`DRET`** → core mới rời Debug Mode. `haltreq` **giữ mức** (không tự xoá, vì
`debug_req` level-sensitive); `resumereq` **tự xoá** vì là sự kiện. Nhớ: hạ
`debug_req` một mình không đủ — chỉ `DRET` mới thoát Debug Mode (mục 5b).

**Reset chip nhưng giữ kết nối.** Chip có ba nguồn reset: POR, watchdog, software.
`SYSDBG` ở **reset domain riêng** — chỉ POR chạm tới, còn watchdog và software
reset **không** đụng nó. Nên software reset lại phần còn lại của chip mà host
**không mất kết nối JTAG**, và halt lại được ngay khi core vừa ra khỏi reset — đó
chính là halt-on-reset.

## Năm mảnh đó, mở ra thành sáu mục

Sáu chứ không phải năm vì ở đây **command FSM và register file tách làm hai** — ở
bài nói chúng là một ý, nhưng là hai module verify riêng. Tài liệu MAS chia mịn hơn
nữa, thành mười sub-block, vì nó tách từng thanh ghi trong scan chain ra.

Dùng khi thầy hỏi "khối đó cụ thể là gì". Mỗi mục: nó là gì, bên trong có gì, chỗ
dễ sai.

### 1. JTAG front-end  (~200 dòng RTL)

Phần duy nhất trong khối mà mình **không** được tự nghĩ ra — chuẩn IEEE 1149.1
quy định sẵn.

| Thành phần | Chi tiết |
|---|---|
| TAP controller | FSM **16 trạng thái**, chỉ lái bằng `TMS`. Phát `capture_dr`, `shift_dr`, `update_dr` và bộ tương ứng cho IR |
| IR | 4 bit **shift** + 4 bit **hold**. Chỉ có hiệu lực tại `update_ir` — đang dịch IR thì DR cũ vẫn đang được chọn |
| DR mux | Chọn `IDCODE` / `ACCESS` / `BYPASS` theo IR hold |
| IDCODE | 32 bit hằng số, nạp tại Capture-DR. Định dạng chuẩn: `[31:28]` version, `[27:12]` part number, `[11:1]` manufacturer, `[0]` = 1 |
| BYPASS | 1 bit, chuẩn bắt buộc |
| ACCESS | 68 bit, thanh ghi lệnh của mình |

**Dễ sai:** `TDI` lấy mẫu ở **cạnh lên** `TCK`, `TDO` đổi ở **cạnh xuống**. Chuẩn
quy định vậy để adapter có đủ thời gian. Làm cùng một cạnh thì chạy được trên mô
phỏng, hỏng trên board.

### 2. Clock domain crossing  (~100 dòng)

Cầu giữa hai vùng clock, hai chiều: lệnh sang system clock, kết quả về `TCK`.

```
phía TCK                          phía system clock
─────────                         ─────────────────
tại Update-DR:
  cmd_reg <= 68 bit               2-flop sync cmd_req
  cmd_req <= ~cmd_req    ───────▶ phát hiện đổi mức
                                  đọc cmd_reg  (đang đứng yên)
                        ◀───────  cmd_ack <= ~cmd_ack
2-flop sync cmd_ack
```

**Điểm cốt lõi:** dữ liệu 68 bit **không** đi qua synchroniser. Chỉ `cmd_req` và
`cmd_ack`, mỗi cái 1 bit. Dữ liệu đứng yên trong thanh ghi suốt thời gian
handshake nên bên nhận đọc lúc nào cũng an toàn. Kỹ thuật này tên là **MCP**
(multi-cycle path formulation). Sync cả 68 bit vừa tốn logic vừa **sai** — mỗi bit
có thể ổn định ở chu kỳ khác nhau, cho ra một giá trị lai chưa từng tồn tại.

**Ràng buộc timing phải khai:** `set_false_path` (hoặc `set_max_delay
-datapath_only`) cho đường dữ liệu. Không khai thì tool cố đóng timing giữa hai
clock không liên quan và báo lỗi vô nghĩa.

Đây là phần cần verify kỹ nhất trong cả khối.

### 3. Command FSM  (~150 dòng)

| State | Làm gì | Ra khi nào |
|---|---|---|
| `IDLE` | Chờ `cmd_req` đổi mức từ CDC | có lệnh, `op != NOP` |
| `DECODE` | Xét `addr[31:28]` | 1 chu kỳ |
| `LOCAL` | Đọc/ghi register file | 1 chu kỳ |
| `BUS` | Lái `mem_req_o`, chờ `gnt` rồi chờ `rsp_valid` | có `rsp_valid` |
| `DONE` | Chốt `rdata`/`status`, phát `rsp_req` | 1 chu kỳ |

**Nên chủ động nói, vì đây là một lỗi em tự tìm ra và sửa.** Bản đầu viết: hết
`BusTimeout` thì **bỏ dở** transaction, trả `status = ERROR`, về `IDLE`. Nghe hợp
lý, nhưng **sai, và sai trong im lặng**. AXI, TL-UL hay `req`/`gnt` đều **không có
cách huỷ** một request đã được `gnt`. Khối bỏ chờ thì response vẫn đang trên đường,
và nó sẽ được giao cho **lệnh kế tiếp** — host nhận dữ liệu của một địa chỉ nó
không hề hỏi, kèm `status = OK`. Một câu trả lời sai im lặng từ debugger còn tệ
hơn treo, vì mọi kết luận sau đó cũng sai theo.

Thiết kế đúng: hết `BusTimeout` thì **báo nhưng không bỏ dở** — chốt
`status = ERROR`, set `STATUS.bus_timeout`, và **tiếp tục chờ**. `busy` vẫn cao nên
lệnh mới bị trả `BUSY`, không bao giờ bị ghép sai. Response về muộn thì **bỏ đi**.
Không về thì `busy` và `bus_timeout` cùng treo, và đó là một **chẩn đoán** chứ
không phải treo: host đọc `STATUS` qua JTAG — đường không phụ thuộc system bus — và
biết chính xác là có slave không trả lời. `dm_sba` trong `riscv-dbg` cũng chọn đúng
cách này, nó phơi `sbbusy_o` và không bao giờ huỷ.

### 4. Register file  (~50 dòng)

Nhỏ nhất về code, nhưng là **giao diện** giữa phần mềm và phần cứng.

| Địa chỉ | Tên | Bit | Kiểu |
|---|---|---|---|
| `0xF000_0000` | `CTRL` | `[0]` haltreq · `[1]` resumereq · `[2]` reserved (reads 0) | RW |
| `0xF000_0004` | `STATUS` | `[0]` busy · `[1]` error · `[2]` cpu_halted · `[3]` bus_timeout | RO |
| `0xF000_0008` | `ID` | version, build | RO |

Hành vi từng bit:

- `haltreq` — **level**, giữ nguyên tới khi phần mềm xoá
- `resumereq` — ghi 1 rồi **tự xoá**, vì nó là một sự kiện chứ không phải trạng thái
- `[2]` — **reserved**, đọc về 0, ghi bị bỏ qua. QSOC **không có debug reset**: chip
  chỉ có ba nguồn reset (POR, watchdog, software), nên `SYSDBG` không phát reset.
  Bit này để trống, không gán lại, để host bản cũ không vô tình kích hoạt chức năng
  khác
- `STATUS` — **tổ hợp thuần**, không lưu trữ. `busy` từ FSM, `cpu_halted` từ
  `debug_mode` đã sync

**Vì sao không nằm trên system bus:** firmware chạy trên CPU không được phép tự
halt mình hay tự cấp quyền debug. Ba thanh ghi này chỉ với tới được qua JTAG.

### 5. Bus master  (~60 dòng)

**Chín tín hiệu**, không phải mười tám như AXI4-Lite:

```
mem_req_o  mem_addr_o  mem_we_o  mem_wdata_o  mem_be_o      ra
mem_gnt_i  mem_rsp_valid_i  mem_rsp_rdata_i  mem_rsp_error_i   vào
```

- **Ghi và đọc giống nhau:** đặt `req` cùng `addr`, `we`, `be`, `wdata`; chờ
  `gnt`; chờ `rsp_valid`; đọc `rdata` và `error`. **Hai handshake, một đường code
  duy nhất.**
- **`mem_be_o`** suy ra từ `size` và bit địa chỉ thấp, đúng như `dm_sba` suy ra
  `be_mask` của nó.
- **Single outstanding** — một lệnh một lúc, nên adapter đặt `MaxRequests = 1`.
- **Ánh xạ lỗi:** `mem_rsp_error_i` một bit, thành `status = ERROR`.

**Vì sao là memory interface mà không phải AXI4-Lite — đây là câu đáng chuẩn bị
nhất.** Ba lý do, theo thứ tự sức nặng:

**1. Hai debug module tham chiếu đều không phát AXI.** Cổng System Bus Access của
`pulp-platform/riscv-dbg`, file `dm_sba.sv`, đúng là giao diện này:
`master_req_o`, `master_add_o`, `master_we_o`, `master_wdata_o`, `master_be_o`,
`master_gnt_i`, `master_r_valid_i`, `master_r_err_i`. Repo đó còn có thêm một
wrapper **OBI** — cũng là request/response — và **không có wrapper AXI nào**.
`rv_dm` của OpenTitan thì dùng TL-UL. Không phải em nghĩ ra, mà là cách khối tương
đương được viết trong thực tế.

**2. Tầng AXI4-Lite vẫn tồn tại, chỉ là do thư viện sinh ra.** Adapter là
`axi_from_mem` trong `pulp-platform/axi`, và bên trong nó **chính là**
`axi_lite_from_mem` nối tiếp `axi_lite_to_axi`. Nên câu hỏi thật không phải
"Lite hay mem", mà là **FSM của em tự làm bước mem sang Lite, hay giao cho module
đã được verify**. Không có lý do gì chọn cái tự viết.

**3. FSM đơn giản hơn thật.** AXI4-Lite ghi một word cần **ba** handshake — AW, W,
rồi B — và `AW` với `W` là hai kênh **độc lập**, master hợp lệ không được deadlock
chờ cái này trước cái kia. Mem thì hai handshake và **giống nhau cho read và
write**. Đây đúng là lập luận em đã dùng để chọn Lite thay vì AXI4 đầy đủ, áp thêm
một bậc nữa.

**Cái phải trả giá, nói thẳng:** mất khả năng cắm AXI VIP ngay tại cổng của khối.
Bù lại em verify **tổ hợp** SYSDBG cộng adapter tại `AXI_S0` — vốn là thứ thật sự
nối vào crossbar — cộng bốn assertion mức mem, lấy `sva/dm_sba_sva.sv` trong chính
repo đó làm mẫu.

**Adapter không thuộc khối em:** nó nằm ở crossbar cùng với các chuyển đổi khác, để
mọi việc đổi protocol do một người sở hữu và verify. `QSOC_HAS` cũng đặt nó ở đó.

### 6. Phần lái `debug_req`  (~30 dòng)

Khối nhỏ nhất, và là lý do tồn tại của cả SYSDBG.

| Tín hiệu | Hướng | Từ/tới |
|---|---|---|
| `debug_req_o` | ra CPU | `= CTRL[0]`, level, giữ |
| `debug_mode_i` | từ CPU | 2-flop sync → `STATUS[2]` |

Hai điểm phải nói được:

1. `debug_req` **không** tự xoá khi CPU dừng. Chỉ `resumereq` mới hạ nó. Vì tín
   hiệu là level-sensitive — xoá sớm thì core có thể chưa kịp thấy.
2. `SYSDBG` **không phát reset** — QSOC bỏ debug reset, chip chỉ còn ba nguồn (POR,
   watchdog, software). Nhưng `SYSDBG` phải nằm ở **reset domain riêng**: software
   reset và watchdog reset **không** được chạm tới nó, chỉ POR mới được. Làm sai
   thì software reset chip xong là mất luôn kết nối debug, đúng lúc cần nó nhất.

### Tổng

Khoảng **700 dòng RTL** — con số này là **em ước lượng**, tài liệu MAS không ghi số
dòng, nên nếu thầy hỏi thì em nói rõ đó là estimate để so độ lớn, không phải cam kết.

Và quan trọng không kém — **những gì không có trong đó**: không abstract command,
không program buffer, không bus slave port. Xin nói chính xác một chỗ: **không có
slave port là đúng và không bao giờ đổi** — kể cả khi đọc thanh ghi CPU. Chuỗi lệnh
cho việc đó nằm trong `ISRAM` và được ghi vào qua master port đã có, nên khối này
chỉ có một cổng bus duy nhất và nó là master.

## Từ điển — chỉ những từ dễ bị hỏi

| Từ | Nói gọn là gì |
|---|---|
| **TAP** | Test Access Port. State machine 16 trạng thái mà **chuẩn JTAG quy định sẵn**, `TMS` lái nó đi. Em không thiết kế nó, em implement cho đúng |
| **IR / DR** | Instruction Register chọn xem thanh ghi nào đang nằm trong scan chain; Data Register là thanh ghi đó. `ACCESS` 68 bit của em là một DR |
| **scan chain** | Một hàng flip-flop nối tiếp, mỗi nhịp `TCK` dịch một bit. **Không có địa chỉ, không có handshake** — nên cả lệnh phải nằm vừa trong một thanh ghi |
| **Update-DR / Capture-DR** | Hai thời điểm chuẩn quy định: Update-DR là "các bit đã chốt", Capture-DR là "nạp giá trị để dịch ra" |
| **CDC** | Clock Domain Crossing. Chuyển dữ liệu giữa hai clock **không liên quan gì nhau** |
| **MCP** | Multi-cycle path. Kỹ thuật CDC em dùng: dữ liệu **đứng yên** trong thanh ghi, chỉ **hai sợi dây** request/acknowledge băng qua |
| **metastability** | Flip-flop lấy mẫu đúng lúc tín hiệu đang đổi thì ra giá trị lập lờ. Hai tầng flip-flop làm xác suất đó nhỏ tới mức bỏ qua được |
| **CSR** | Control and Status Register, nằm **bên trong** CPU. **Không có địa chỉ trên bus** — đây là toàn bộ lý do phải bắt core tự thực thi lệnh store để đọc nó |
| **`debug_req`** | Một sợi dây duy nhất vào CPU. **Level-sensitive**, nên phải **giữ** mức, không đánh xung |
| **Debug Mode** | Chế độ core vào khi dừng. Ngắt bị bỏ qua, `dret` thành hợp lệ, và core fetch từ `DmHaltAddr` |
| **`ndmreset`** | Non-debug-module reset trong chuẩn RISC-V: khối debug reset cả chip trừ chính nó. **QSOC đã bỏ** — chip chỉ có ba nguồn reset (POR, watchdog, software), nên `SYSDBG` không phát reset; `CTRL[2]` để reserved. Việc "reset mà không mất kết nối" giờ đạt được bằng cách đặt `SYSDBG` ở reset domain riêng, chỉ POR chạm tới |
| **Program Buffer** | Cách chuẩn: đặt lệnh **bên trong** khối debug cho core fetch — nên khối debug phải là **slave**. Của em đặt trong `ISRAM` nên không cần |

## Ngân hàng câu hỏi

**Sao không dùng luôn `riscv-dbg`?**
Vì đề bài là **thiết kế** khối này, và vì `riscv-dbg` lớn hơn nhiều so với nhu cầu
của mình — abstract command, program buffer, system bus access, một DMI tuân thủ
đầy đủ spec. Em đọc nó rất kỹ và dùng nó làm **tài liệu tham chiếu** để biết một
debug module cần làm được gì, và để lấy các hằng số địa chỉ mà CPU cần. Nhưng bản
QSOC cần thì nhỏ hơn, và em làm được.

**Sao lại 68 bit? Sao không dùng thanh ghi nhỏ hơn và scan nhiều lần?**
Vì một lần scan cho một lệnh giữ cho phần mềm host đơn giản và FSM cũng đơn giản.
Hai bit opcode, hai bit `size`, 32 bit địa chỉ, 32 bit dữ liệu là mức tối thiểu chở
trọn một lệnh. Thanh ghi DMI của `riscv-dbg` về cơ bản cũng cùng hình dạng đó.

**Sao cần hai bit `size`? Ghi cả word không đủ à?**
Không đủ. QSOC là RV32I**MC**, lệnh compressed dài **hai byte**, nên đặt software
breakpoint lên nó là một lần ghi **halfword** — chỉ ghi word được thì đè luôn lệnh
bên cạnh.

**Sao là memory interface mà không phải AXI4-Lite hay AXI đầy đủ?**
Vì `dm_sba.sv` của `riscv-dbg` dùng đúng giao diện này, và `rv_dm` của OpenTitan
dùng TL-UL — **không debug module tham chiếu nào phát AXI**. Thêm nữa tầng AXI4-Lite
vẫn có, chỉ là do `axi_from_mem` sinh ra thay vì FSM của em tự viết. Và mem chỉ cần
hai handshake giống nhau cho read và write, thay vì ba với `AW`/`W` độc lập. Chi
tiết ở khối 5 của Phần II.

**Timeout thì bỏ dở transaction à?**
Không. Không bus nào cho **huỷ** một request đã `gnt`, nên bỏ dở thì response về
muộn sẽ bị ghép cho **lệnh sau** — sai trong im lặng, tệ hơn treo. Em **báo mà vẫn
chờ**: `ERROR` cộng `STATUS.bus_timeout`, `busy` giữ cao, response muộn thì bỏ. Đây
là một lỗi em tự tìm ra và sửa; lập luận đầy đủ ở khối 3 của Phần II.

**Clock của khối debug có bị gate được không?**
Không được phép. TAP chạy trên `tck_i`, nên gate `clk_i` **không** dừng phía JTAG:
host vẫn shift lệnh vào và lệnh vẫn được latch, nhưng không có gì thực thi — FSM
đóng băng, mọi scan trả `BUSY`, không phân biệt được với slave chết. Tức đóng được
gate này là **vô hiệu hoá debugger trong im lặng**. `QSOC_HAS` cho khối em `D15`
bit 14, mặc định mở, software không đóng được; em đã ký xác nhận.

**Halt-on-reset có cần không?**
Cần, và nó là **yêu cầu về thứ tự reset** chứ không phải tính năng của khối em:
`debug_req` phải đã cao lúc core ra khỏi reset, nên `SCRC` thả `SYSDBG` **trước**
core, không có handshake để chờ. Lý do quyết định: ROM chứa **serial bootloader**
thật, nên lỗi ROM là lỗi trong code thật. Cùng tiền đề đó làm hardware trigger
thành cần thiết, vì breakpoint mềm không ghi được vào ROM.

**Nếu host gửi lệnh mới khi lệnh trước chưa xong thì sao?**
Nó đọc về `BUSY` chứ không nhận kết quả hỏng. Chỗ này em làm có chủ ý: nhờ vậy
phần mềm host không cần mô hình timing của chip.

**Sao clock domain crossing lại là một vấn đề riêng?**
Vì `TCK` do board debug trên bàn em phát ra, hoàn toàn không liên quan tới clock
của chip — và nó **dừng** giữa hai lệnh. Nên em chốt lệnh đúng một lần, tại
Update-DR, đưa qua như một khối nguyên vẹn với request và acknowledge, và dùng hai
tầng flip-flop đồng bộ. Ngoài ra không có gì khác đi qua ranh giới. Em muốn tách
nó thành một module nhỏ riêng để verify độc lập.

**Cái này có phải vấn đề bảo mật không?**
Có, và nên nói ra chứ không nên lờ đi. SYSDBG là một bus master ghi được mọi nơi,
mà QSOC lại chưa có life cycle controller, nên hiện tại nó luôn truy cập được. Với
một bản demo trên FPGA thì chấp nhận được. Sản phẩm thật thì phải khoá được đường
debug.

**Phần khó nhất là gì?**
Clock domain crossing, và việc đặt đúng `DmHaltAddr` với `DmExceptionAddr`. Cả hai
đều thuộc loại lỗi không lộ ra ngay, mà tới lúc mình đang dùng chính cái công cụ
hỏng đó để debug thứ khác thì mới lộ.

---
## Bản ba phút

Nếu ít thời gian thì chỉ nói đúng chừng này:

CPU chỉ có đúng một input cho debug là `debug_req`. Khi nó lên mức 1, core lưu PC
vào `dpc`, ghi lý do vào `dcsr`, nhảy tới một địa chỉ cố định và vào Debug Mode.
Tín hiệu này là level-sensitive nên phải **giữ**.

SYSDBG là khối in-house biến một sợi dây đó thành một debugger. Nó kết thúc JTAG,
băng từ clock của board debug sang clock của chip, giải mã một lệnh 68 bit, rồi
hoặc ghi thanh ghi nội bộ của nó, hoặc phát một bus request. Một lần scan là một
lệnh; kết quả về ở lần scan kế tiếp.

Halt là: PC gọi `halt()`, một lần scan, FSM set `CTRL[0]`, `debug_req` lên 1, core
dừng, `STATUS[2]` lên 1, lần scan sau mang nó về.

Thứ duy nhất nó không làm được là đọc thanh ghi CPU, vì thanh ghi không có địa chỉ
trên bus. Cách làm là **bắt chính core thực thi một lệnh store** rồi đọc chỗ nó vừa
ghi — và điểm đáng nói là việc đó **không thêm cổng phần cứng nào**: chuỗi lệnh nằm ở
4 KiB đầu của `ISRAM` vốn đã là slave, và `SYSDBG` ghi vào đó bằng chính master port
đang có. Một debug module chuẩn thì đặt Program Buffer bên trong nó, và như vậy là
buộc thành slave. Giới hạn duy nhất: đọc thanh ghi thì **phải halt core**, đọc bộ nhớ
thì không.

Và để không cần debug ROM, em xin thêm một sợi dây từ CPU là `debug_mode`, vốn đã tồn
tại sẵn trong Ibex và chỉ là chưa nối ra chân.
