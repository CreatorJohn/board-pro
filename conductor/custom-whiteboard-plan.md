# Custom Whiteboard Implementation Plan

## Background & Motivation
The goal is to create a custom whiteboard Flutter application from scratch. The user needs the ability to create, save, and load whiteboards locally. The whiteboard will support various objects including freehand drawings (with adjustable thickness and color), text, images, and multi-page PDFs (where each page is extracted and inserted as an image). Every object on the board must be selectable, movable, resizable, and removable.

## Scope & Impact
- **Tech Stack:** Flutter (Desktop/Web/Mobile compatible, though focused on local file system usage).
- **Architecture:** Widget-based canvas using `Stack` and `Positioned` widgets. Each element (drawing, text, image, PDF page) is an individual object in the stack.
- **State Management:** Riverpod (`flutter_riverpod`).
- **Storage:** Local File System using `path_provider` and JSON serialization to save and load board states.
- **Dependencies:** `flutter_riverpod`, `file_picker` (for images/PDFs), `pdfx` (for rendering PDF pages to images), `uuid` (for unique object IDs), `path_provider` (for local storage).

## Proposed Solution
1.  **Project Initialization:** Create a new Flutter project in the current directory and install dependencies.
2.  **Data Models:** Create classes for `Whiteboard`, `BoardObject` (abstract), and its subclasses: `DrawingObject`, `TextObject`, `ImageObject`. Each object will have properties for position (x, y), size (width, height), rotation, and z-index.
3.  **State Management:** Implement Riverpod Notifiers to manage the current active whiteboard, the list of saved whiteboards, and the state of the canvas (currently selected object, current drawing settings).
4.  **Canvas UI:**
    -   A main `Stack` widget to hold all objects.
    -   A `GestureDetector` over the `Stack` to handle tapping (deselecting), and dragging (for freehand drawing when drawing mode is active).
    -   Individual wrapper widgets for each `BoardObject` that handle their own tap-to-select, drag-to-move, and drag-corners-to-resize logic.
    -   Freehand drawings will use a `CustomPaint` widget sized to the drawing's bounding box.
5.  **Toolbar UI:** A toolbar for switching tools (Select, Draw, Text, Image, PDF), changing color/thickness, and saving/loading boards.
6.  **PDF/Image Handling:** When a user inserts an image, it's read and added as an `ImageObject`. When a PDF is selected, `pdfx` will render each page to an image, and each page will be sequentially placed onto the canvas as an `ImageObject`.
7.  **Storage:** The `Whiteboard` object will have `toJson` and `fromJson` methods. Boards will be saved as `.json` files in the app's document directory.

## Implementation Plan

### Phase 1: Setup and Data Layer
1.  Run `flutter create . --empty` (or standard).
2.  Add dependencies: `flutter_riverpod`, `file_picker`, `pdfx`, `uuid`, `path_provider`.
3.  Define the object models (`BoardObject`, `DrawingObject`, `TextObject`, `ImageObject`) with `copyWith` and JSON serialization methods.

### Phase 2: State Management
1.  Create `WhiteboardNotifier` to manage the list of objects on the current board.
2.  Create `ToolNotifier` to manage the currently selected tool (Draw, Select, etc.), drawing color, and thickness.
3.  Create `StorageNotifier` to handle saving and loading whiteboards to/from the local file system.

### Phase 3: Canvas and Interactions
1.  Build the `WhiteboardCanvas` widget using a `Stack`.
2.  Implement `ObjectWrapper` widget to provide selection boundaries, movement handles, and resize handles.
3.  Implement drawing logic: capturing `PanUpdate` events to build a `Path`, and rendering it via `CustomPainter`.
4.  Implement Text and Image rendering inside the `ObjectWrapper`.

### Phase 4: Media Insertion and Toolbar
1.  Build the `Toolbar` UI.
2.  Implement `file_picker` logic for picking images and PDFs.
3.  Integrate `pdfx` to convert PDF pages into a list of images, adding them to the board state.
4.  Implement Save/Load dialogs or sidebars.

## Verification
-   **Drawing:** Verify freehand drawing creates smooth paths and responds to color/thickness changes.
-   **Transformations:** Verify all object types can be selected, moved, resized, and deleted independently.
-   **Media:** Verify inserting a 3-page PDF creates 3 separate image objects on the canvas.
-   **Persistence:** Verify that saving a board, clearing it, and loading it restores all objects exactly as they were.

## Migration & Rollback
-   Since this is a greenfield project, there is no legacy data to migrate. If critical issues occur during development, we will revert the specific Git commits or stash changes.
