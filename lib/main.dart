import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  runApp(const DigitalLinkApp());
}

class DigitalLinkApp extends StatelessWidget {
  const DigitalLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Digital-Link Pattern',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.cyanAccent,
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        useMaterial3: true,
      ),
      home: const ConnectScreen(),
    );
  }
}

// --- DATA MODELS ---

enum WireType { positive, negative }

class WirePath {
  final WireType type;
  final List<int> pinIndices;

  WirePath({required this.type, required this.pinIndices});

  Map<String, dynamic> toJson() {
    return {'type': type.name, 'pins': pinIndices};
  }

  factory WirePath.fromJson(Map<String, dynamic> json) {
    return WirePath(
      type: WireType.values.byName(json['type']),
      pinIndices: List<int>.from(json['pins']),
    );
  }
}

// --- SCREEN 1: CONNECTION (QR SCANNER) ---

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _scannerController;
  final MobileScannerController cameraController = MobileScannerController();

  @override
  void initState() {
    super.initState();
    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      cameraController.stop();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const PatternCircuitScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera View
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
            // errorBuilder removed to prevent version conflicts
          ),

          // 2. Scanner Overlay
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    // FIXED: Using .withValues instead of .withOpacity
                    border: Border.all(
                      color: Colors.cyanAccent.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                // Scanning Laser Line
                AnimatedBuilder(
                  animation: _scannerController,
                  builder: (context, child) {
                    return Positioned(
                      top: 40 + (_scannerController.value * 200),
                      child: Container(
                        width: 260,
                        height: 2,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withValues(alpha: 0.8),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                          color: Colors.redAccent,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // 3. UI Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black, Colors.transparent],
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    "Scan Digital-Link QR",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Align the QR code within the frame to connect.",
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),

                  // SIMULATE SCAN BUTTON
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const PatternCircuitScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text("SIMULATE SCAN"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 16,
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- SCREEN 2: MAIN CIRCUIT BOARD ---

class PatternCircuitScreen extends StatefulWidget {
  const PatternCircuitScreen({super.key});

  @override
  State<PatternCircuitScreen> createState() => _PatternCircuitScreenState();
}

class _PatternCircuitScreenState extends State<PatternCircuitScreen> {
  // 1. STATE VARIABLES
  WireType currentTool = WireType.positive; // Default tool
  List<WirePath> completedPaths = []; // Finished wires
  List<int> currentDragPath = []; // The wire currently being drawn
  Offset? currentDragPosition; // Exact finger position

  // Layout Constants
  final int rows = 4;
  final int cols = 4;

  // --- IMPORT / EXPORT LOGIC ---

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _exportLayout() {
    List<Map<String, dynamic>> jsonList = completedPaths
        .map((e) => e.toJson())
        .toList();
    String jsonString = jsonEncode(jsonList);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Save Layout"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Copy this code:",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.black54,
              child: SelectableText(
                jsonString,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _copyToClipboard(jsonString, "Layout copied!");
              Navigator.pop(ctx);
            },
            child: const Text(
              "COPY",
              style: TextStyle(color: Colors.cyanAccent),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CLOSE"),
          ),
        ],
      ),
    );
  }

  void _importLayout() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    TextEditingController controller = TextEditingController(
      text: data?.text ?? "",
    );

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Import Layout"),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: "Paste layout JSON here...",
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.black54,
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () {
              try {
                List<dynamic> jsonList = jsonDecode(controller.text);
                List<WirePath> newPaths = jsonList
                    .map((e) => WirePath.fromJson(e))
                    .toList();

                setState(() {
                  completedPaths = newPaths;
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Loaded successfully!"),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Invalid JSON!"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              "LOAD",
              style: TextStyle(color: Colors.cyanAccent),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL"),
          ),
        ],
      ),
    );
  }

  void _exportPCB() {
    Map<String, dynamic> pcbData = {
      "project_name": "Digital-Link Custom PCB",
      "timestamp": DateTime.now().toIso8601String(),
      "nets": {"VCC": [], "GND": []},
      "routing_instructions": "Connect pins using 0.5mm traces.",
    };

    for (var path in completedPaths) {
      String netName = path.type == WireType.positive ? "VCC" : "GND";
      pcbData["nets"][netName].add(path.pinIndices);
    }

    String pcbJson = const JsonEncoder.withIndent('  ').convert(pcbData);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Export PCB Design"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Manufacturing File (Netlist):",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              height: 150,
              width: double.maxFinite,
              padding: const EdgeInsets.all(10),
              color: Colors.black54,
              child: SingleChildScrollView(
                child: SelectableText(
                  pcbJson,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _copyToClipboard(pcbJson, "PCB File copied!");
              Navigator.pop(ctx);
            },
            child: const Text(
              "COPY FILE",
              style: TextStyle(color: Colors.cyanAccent),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CLOSE"),
          ),
        ],
      ),
    );
  }

  // --- GESTURE LOGIC ---

  int _getPinIndexFromOffset(Offset localPosition, Size size) {
    double cellWidth = size.width / cols;
    double cellHeight = size.height / rows;
    int col = (localPosition.dx / cellWidth).floor();
    int row = (localPosition.dy / cellHeight).floor();
    if (col < 0 || col >= cols || row < 0 || row >= rows) return -1;
    return row * cols + col;
  }

  bool _isOrthogonal(int indexA, int indexB) {
    int rA = indexA ~/ cols;
    int cA = indexA % cols;
    int rB = indexB ~/ cols;
    int cB = indexB % cols;
    bool sameRow = rA == rB;
    bool adjCol = (cA - cB).abs() == 1;
    bool sameCol = cA == cB;
    bool adjRow = (rA - rB).abs() == 1;
    return (sameRow && adjCol) || (sameCol && adjRow);
  }

  // LOGIC: INITIAL TOUCH (Resume or Start)
  void _onPanStart(DragStartDetails details, Size size) {
    Offset localPosition = details.localPosition;
    int index = _getPinIndexFromOffset(localPosition, size);

    setState(() {
      currentDragPosition = localPosition;
    });

    if (index == -1) return;

    setState(() {
      // CHECK 1: RESUME MODE
      // If we touch the END of an existing wire of the same color...
      int existingPathIndex = completedPaths.indexWhere(
        (path) => path.type == currentTool && path.pinIndices.last == index,
      );

      if (existingPathIndex != -1) {
        // ... "Pick it up" (Move from completed to active dragging)
        currentDragPath = List.from(
          completedPaths[existingPathIndex].pinIndices,
        );
        completedPaths.removeAt(existingPathIndex);
        return;
      }

      // CHECK 2: START NEW
      bool startCollision = completedPaths.any(
        (path) => path.type != currentTool && path.pinIndices.contains(index),
      );

      if (!startCollision) {
        currentDragPath = [index];
      }
    });
  }

  // LOGIC: DRAGGING (Add or Rewind)
  void _onPanUpdate(DragUpdateDetails details, Size size) {
    Offset localPosition = details.localPosition;
    int index = _getPinIndexFromOffset(localPosition, size);

    setState(() {
      currentDragPosition = localPosition;

      if (index == -1) return;
      if (currentDragPath.isEmpty) return;

      if (index == currentDragPath.last) return;

      if (_isOrthogonal(currentDragPath.last, index)) {
        // REWIND LOGIC: If we move back over our own path
        int existingIndex = currentDragPath.indexOf(index);
        if (existingIndex != -1) {
          currentDragPath.removeRange(
            existingIndex + 1,
            currentDragPath.length,
          );
          return;
        }

        // ADD LOGIC: If no collision
        bool isOppositeCollision = completedPaths.any(
          (path) => path.type != currentTool && path.pinIndices.contains(index),
        );

        if (!isOppositeCollision) {
          currentDragPath.add(index);
        }
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      if (currentDragPath.length > 1) {
        completedPaths.add(
          WirePath(type: currentTool, pinIndices: List.from(currentDragPath)),
        );
      }
      currentDragPath = [];
      currentDragPosition = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pattern Circuit"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: () {
              if (completedPaths.isNotEmpty) {
                setState(() {
                  completedPaths.removeLast();
                });
              }
            },
            tooltip: "Undo Last Wire",
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'save') _exportLayout();
              if (value == 'load') _importLayout();
              if (value == 'pcb') _exportPCB();
              if (value == 'clear') {
                setState(() {
                  completedPaths.clear();
                  currentDragPath.clear();
                });
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'save',
                child: Row(
                  children: [
                    Icon(Icons.save, color: Colors.white70),
                    SizedBox(width: 10),
                    Text('Save Layout'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'load',
                child: Row(
                  children: [
                    Icon(Icons.upload_file, color: Colors.white70),
                    SizedBox(width: 10),
                    Text('Import Layout'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'pcb',
                child: Row(
                  children: [
                    Icon(Icons.print, color: Colors.cyanAccent),
                    SizedBox(width: 10),
                    Text(
                      'Export PCB',
                      style: TextStyle(color: Colors.cyanAccent),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.redAccent),
                    SizedBox(width: 10),
                    Text(
                      'Clear Board',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final Size size = constraints.biggest;

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (details) => _onPanStart(details, size),
                    onPanUpdate: (details) => _onPanUpdate(details, size),
                    onPanEnd: _onPanEnd,
                    child: Stack(
                      children: [
                        CustomPaint(
                          size: Size.infinite,
                          painter: CircuitPainter(
                            savedPaths: completedPaths,
                            currentPath: currentDragPath,
                            currentTool: currentTool,
                            dragPosition: currentDragPosition,
                            cols: cols,
                            rows: rows,
                          ),
                        ),
                        // Pins Grid
                        Column(
                          children: List.generate(rows, (rowIndex) {
                            return Expanded(
                              child: Row(
                                children: List.generate(cols, (colIndex) {
                                  return Expanded(
                                    child: Center(
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF404040),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white30,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const Divider(height: 1, color: Colors.white24),
          Container(
            color: const Color(0xFF252525),
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildToolButton(
                  WireType.positive,
                  "POSITIVE (+)",
                  Colors.redAccent,
                ),
                _buildToolButton(
                  WireType.negative,
                  "NEGATIVE (-)",
                  Colors.cyanAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton(WireType type, String label, Color color) {
    bool isSelected = currentTool == type;
    return GestureDetector(
      onTap: () => setState(() => currentTool = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          // FIXED: Using .withValues
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade700,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.flash_on,
              color: isSelected ? color : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CircuitPainter extends CustomPainter {
  final List<WirePath> savedPaths;
  final List<int> currentPath;
  final WireType currentTool;
  final Offset? dragPosition;
  final int cols;
  final int rows;

  CircuitPainter({
    required this.savedPaths,
    required this.currentPath,
    required this.currentTool,
    this.dragPosition,
    required this.cols,
    required this.rows,
  });

  Offset _getPinCenter(int index, Size size) {
    double cellW = size.width / cols;
    double cellH = size.height / rows;
    int c = index % cols;
    int r = index ~/ cols;
    return Offset((c * cellW) + (cellW / 2), (r * cellH) + (cellH / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (var path in savedPaths) {
      Paint paint = Paint()
        ..color = path.type == WireType.positive
            ? Colors.redAccent
            : Colors.cyanAccent
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      paint.maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);
      _drawPath(canvas, path.pinIndices, paint, size);
    }

    if (currentPath.isNotEmpty) {
      Paint paint = Paint()
        ..color = currentTool == WireType.positive
            ? Colors.redAccent
            : Colors.cyanAccent
        ..strokeWidth = 8.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      _drawPath(canvas, currentPath, paint, size);

      if (dragPosition != null) {
        Offset lastPinCenter = _getPinCenter(currentPath.last, size);
        canvas.drawLine(lastPinCenter, dragPosition!, paint);
      }
    }
  }

  void _drawPath(Canvas canvas, List<int> indices, Paint paint, Size size) {
    if (indices.length < 2) return;
    Path path = Path();
    Offset start = _getPinCenter(indices[0], size);
    path.moveTo(start.dx, start.dy);
    for (int i = 1; i < indices.length; i++) {
      Offset p = _getPinCenter(indices[i], size);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
