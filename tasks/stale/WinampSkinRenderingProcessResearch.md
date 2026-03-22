

# **Deconstructing the Classic Winamp Rendering Engine: A Sequential Analysis of the Skin Compositing Pipeline**

## **Introduction to the Bitmap-Replacement Architecture**

### **Defining the Paradigm**

The Winamp classic skinning engine, which powered the visual customization of one of the most iconic media players of the late 1990s and early 2000s, operates on a "bitmap-replacement" model.1 This architectural paradigm is fundamentally static, relying on a predefined set of bitmap image files (.bmp) with hardcoded dimensions and coordinates to construct the graphical user interface (GUI). Unlike its successors, the "Modern" skins introduced with Winamp3, the classic engine does not utilize dynamic or declarative layout systems such as XML or scripting languages to define the interface.2 Instead, its core function is to replace a default set of internal image assets with user-provided ones found within a skin archive. This approach allows for profound aesthetic alteration without changing the underlying form or function of the player's interface elements.4  
A critical architectural constraint of this engine is its lack of native support for alpha channel transparency.5 This limitation profoundly influences the skinning process and the rendering logic itself. To create the illusion of non-rectangular or transparent elements, such as buttons that blend seamlessly with a custom background, skin designers must manually copy the corresponding section of the main background image (main.bmp) into the bitmap files for those foreground elements.5 This technique is not merely a stylistic choice but a mandatory workaround for a fundamental engine limitation. Consequently, the entire rendering process can be understood as a system designed around the capabilities and constraints of the Graphics Device Interface (GDI) bitmap operations of its era, imposing a specific and rigid workflow on both the engine's rendering sequence and the skin designer's asset creation process.

### **Report Objective and Methodology**

The primary objective of this report is to reverse-engineer and document the precise, sequential rendering pipeline employed by the classic Winamp engine to composite these disparate bitmap assets into a coherent and functional GUI. This process is analogous to a "Painter's Algorithm," where elements are drawn in a strict back-to-front order to create the final layered image. Due to the scarcity of official, in-depth developer documentation from the period, this analysis is a work of reconstruction. It synthesizes technical details gleaned from official skinning tutorials, community-authored guides, and the implicit logic embedded within the structure of the skin files themselves.6 The methodology involves systematically mapping each visible UI component to its source bitmap file, deconstructing the sprite layouts within those files, and inferring the Z-order (the drawing sequence) based on explicit descriptions of layering and the technical necessities of certain rendering orders found in historical skinning resources.5

## **Anatomy of a Classic Skin Archive (.wsz)**

### **The .wsz File Format**

The .wsz file, the standard distribution format for a classic Winamp skin, is not a proprietary or complex container. It is, in fact, a standard .zip archive where the file extension has been renamed from .zip to .wsz.2 This was a strategic decision by Nullsoft, Winamp's original developer, to create a unique file association. By using a custom extension, they could configure Windows to automatically open .wsz files with Winamp for installation, thereby avoiding conflicts with the many other applications that utilized the ubiquitous .zip format.8 When a user initiates the installation of a .wsz file, Winamp's executable simply copies the file into its Skins subdirectory. From that location, the skinning engine can read the contents of the archive directly, treating it as a standard zip file without needing to decompress it into a permanent folder.8

### **Standardized File Structure**

The classic skinning engine is designed to look for a specific, flat collection of named files within the .wsz archive or a corresponding subfolder in the Skins directory. The engine's robustness is enhanced by a fallback mechanism: for any required asset file that it fails to locate within the skin, it reverts to using a built-in, default version of that asset.7 This design choice allows for the creation of "partial" skins, where a designer might only modify a select few graphical elements while leaving the rest of the interface with its default appearance. The primary assets that constitute a skin are a collection of .bmp files, which contain all the graphical data. These are supplemented by optional .cur files for custom mouse cursors and a few .txt files that provide configuration data for colors, fonts, and window shapes.11

| Filename | Target Window | UI Component | Primary Function | Source(s) |
| :---- | :---- | :---- | :---- | :---- |
| main.bmp | Main | Main Window Background | Provides the foundational 275x116 pixel canvas for the main player. | 5 |
| titlebar.bmp | Main | Title Bar & Window Controls | Contains sprites for the active/inactive title bar, windowshade mode, and corner buttons. | 7 |
| cbuttons.bmp | Main | Playback Controls | Contains sprites for Previous, Play, Pause, Stop, Next, and Eject buttons. | 5 |
| shufrep.bmp | Main | Toggles & Window Buttons | Contains sprites for Shuffle, Repeat, EQ, and Playlist toggle buttons. | 5 |
| volume.bmp | Main | Volume Slider | Contains pre-rendered states of the volume bar and the slider knob. | 5 |
| balance.bmp | Main | Balance Slider | Contains pre-rendered states of the balance bar and the slider knob. | 5 |
| posbar.bmp | Main | Position/Seek Bar | Contains the graphics for the song progress bar and its slider knob. | 7 |
| monoster.bmp | Main | Status Indicators | Provides the "Mono" and "Stereo" indicator lights. | 5 |
| playpaus.bmp | Main | Playback Status Indicators | Provides the small Play/Pause/Stop icons next to the time display. | 5 |
| numbers.bmp | Main | Time Display Digits | A sprite sheet containing images for the digits 0-9 for the timer. | 5 |
| text.bmp | Main | Song Title Characters | A sprite sheet containing the character set for the scrolling song title. | 5 |
| eqmain.bmp | Equalizer | Equalizer Window | The main background and frame for the graphic equalizer window. | 7 |
| pledit.bmp | Playlist | Playlist Editor Window | The main background and frame for the playlist editor window. | 7 |
| gen.bmp | General | General Purpose Window Frame | Provides resizable frame elements (corners, edges) for windows like the Media Library. | 13 |
| genex.bmp | General | General Purpose Window Elements | Contains buttons, sliders, and embedded color configuration data for general windows. | 13 |

## **The Rendering Canvas — Compositing the Main Player Window**

The construction of the main player window is the most intricate operation performed by the classic skinning engine. It follows a strict Painter's Algorithm, meticulously drawing graphical elements from back to front in a predetermined sequence to build the final user interface. Each step involves cropping a specific region from a source bitmap and "blitting" (a bit-block transfer) it onto an off-screen composition buffer.

### **Layer 0: The Foundation (main.bmp)**

The rendering process for the main window invariably begins with the main.bmp file. This bitmap, with standard dimensions of 275x116 pixels, serves as the foundational canvas upon which all other elements of the main player window are drawn.9 It is consistently described in skinning guides as the "heart of the skin" and the "background picture".7 Crucially, multiple sources explicitly state that other images are drawn *over* it, which firmly establishes main.bmp as the absolute lowest layer in the Z-order, the first element to be placed in the rendering buffer.5

### **Layer 1: Primary Structural Overlay (titlebar.bmp)**

Immediately after the main.bmp canvas is laid down, the engine processes titlebar.bmp. This file is a sprite sheet containing the various graphical states of the window's top bar.5 The rendering logic is explicit and unwavering: "The top part of anything drawn in main.bmp will always be covered by one of the two top parts in this file".7 This confirms its rendering position directly atop the corresponding upper region of the main.bmp canvas.  
The engine's logic selects which specific sprite to render from titlebar.bmp based on the window's current state. One horizontal strip of the bitmap is used when the Winamp window has desktop focus (the active state), and another is used when it is inactive.5 Additional sprites within this same file define the appearance of the player when it is collapsed into "WindowShade" mode, and even contain graphics for a special Easter egg state.5 This file also provides the graphics for the small control buttons—minimize, maximize/restore, and close—that are located in the corners of the title bar.7

### **Layer 2: Interactive Element Compositing (A Sequential Analysis)**

With the foundational background and title bar in place, the engine proceeds to render the various interactive UI elements. These are not drawn as whole files but are instead precise regions cropped from their respective sprite sheets and blitted onto the composition buffer at hardcoded coordinates.

#### **Playback Controls (cbuttons.bmp)**

This 136x36 pixel bitmap contains the sprite data for the five primary playback buttons (Previous, Play, Pause, Stop, Next) and the Eject button.15 The file is structured as a simple sprite sheet with two horizontal rows. The top row contains the graphics for the buttons in their default, un-pressed (normal) state. The bottom row contains the graphics for the same buttons in their pressed state.5 When the user clicks a button, the engine swaps the rendered sprite from the top row to the corresponding one in the bottom row to provide visual feedback.

#### **State Toggles (shufrep.bmp)**

This bitmap governs the appearance of the Shuffle and Repeat buttons, as well as the buttons that toggle the visibility of the Equalizer and Playlist windows.5 These elements are more complex than simple playback controls because they have two independent states: a toggle state (on or off) and a pressed state (mouse down or up). The shufrep.bmp sprite sheet accommodates this by providing four distinct images for each button, laid out in a specific, hardcoded sequence that the engine is built to read: "unpressed off, pressed off, unpressed on, pressed on".2 This reveals that the rendering engine is not just performing simple bitmap replacement; it functions as a finite state machine. For each interactive element, the engine tracks its current state (e.g., is\_shuffle\_on, is\_mouse\_button\_down) and uses this information to calculate the precise source coordinates within the sprite sheet from which to crop the correct visual representation.

#### **Dynamic Displays (Sliders)**

The sliders for Volume (volume.bmp), Balance (balance.bmp), and song Position (posbar.bmp) are composited next. These are among the most complex graphical elements. The volume.bmp file, for instance, does not contain a simple track and knob that are drawn separately. Instead, it contains a vertical strip of 28 pre-rendered images of the entire volume bar, each depicting a different level, alongside separate graphics for the slider knob itself.5 To display the volume at 50%, the engine does not draw a progress bar; it selects and displays the 14th complete bar image from the sprite sheet, and then overlays the slider knob graphic at the appropriate vertical position. The balance.bmp and posbar.bmp files function in a virtually identical manner.5

#### **Status Indicators (playpaus.bmp, monoster.bmp)**

Finally, small, non-interactive indicator icons are drawn to provide passive feedback to the user. The playpaus.bmp file contains the small icons for Play, Pause, and Stop that appear to the left of the main time display, reflecting the current playback status.5 The monoster.bmp file contains the simple indicator lights that show whether the currently playing audio is in Mono or Stereo mode.5

### **Layer 3: Alphanumeric Rendering (numbers.bmp, text.bmp)**

Among the final layers to be rendered are the alphanumeric displays for the timer and the scrolling song title. To ensure a consistent aesthetic that matches the skin, this text is not rendered using standard system fonts. Instead, Winamp employs a character-sprite system, treating letters and numbers as individual images.  
The numbers.bmp file is a sprite sheet containing graphical representations of the digits 0 through 9\.5 To display a time like "3:45," the engine's rendering logic individually crops the '3', '4', and '5' sprites from numbers.bmp and assembles them sequentially in the time display area of the composition buffer. The colon is a separate, special character on the sprite sheet. An interesting detail is that the negative sign, used when displaying time remaining, is not its own sprite; the engine instead uses the middle row of pixels from the '8' sprite to draw it.15 The text.bmp file functions identically but contains the full character set required for displaying the scrolling song title, giving skinners complete control over the typography of the main display.5

## **Assembly of Auxiliary Windows**

Beyond the main player, the classic skin engine is responsible for rendering several auxiliary windows, each with its own set of dedicated bitmap assets and rendering logic.

### **The Equalizer (eqmain.bmp, eq\_ex.bmp)**

The main graphic equalizer window is constructed primarily from eqmain.bmp. This single 275x116 pixel bitmap provides the window's background frame, title bar, on/off and auto buttons, and presets button.7 A notable optimization within the engine is how it renders the ten vertical EQ band sliders and the preamp slider. These are not defined as unique graphics in the bitmap; instead, a single graphical representation of a slider bar is drawn repeatedly for each band.2 The collapsed "windowshade" mode for the equalizer is defined in a separate file, eq\_ex.bmp, which contains the graphics for the compact bar and its embedded volume and balance sliders.7

### **The Playlist Editor (pledit.bmp)**

The entire graphical frame for the playlist editor is contained within a single bitmap file, pledit.bmp.7 This asset includes the window's title bar, control buttons (add, remove, sort, etc.), and the graphical elements for the scrollbar. Unlike the main window's timer and song title, the actual text within the playlist (the track listings) is rendered using standard Windows system fonts. The specific font face and colors used are defined in the pledit.txt configuration file, not in a bitmap.

### **General Purpose Windows (gen.bmp, genex.bmp)**

Introduced in Winamp version 2.9 and later, these assets are used to render more complex, resizable windows, such as the Media Library and the integrated visualization studio.12

* gen.bmp defines the window's frame using a method analogous to 9-slice scaling. The bitmap is divided into distinct sections for the corners, the top, bottom, and side edges, and the central background area. When the user resizes the window, the corner pieces remain fixed in size, while the edge pieces are tiled (repeated) horizontally or vertically, and the center area is tiled in both directions. This allows for an efficiently drawn, fully resizable window frame.16  
* genex.bmp is a sprite sheet for the buttons and sliders used within these general-purpose windows. However, it also contains a highly unconventional and clever configuration mechanism. A specific horizontal row of single pixels at the top right of the image is not intended to be drawn to the screen. Instead, the engine reads the RGB color value of each pixel at a specific, hardcoded coordinate and uses that color to style a particular UI element.2 For example, the color of the pixel at coordinate (48, 0\) defines the background color for all list views and text entry boxes within that window. This technique effectively embeds configuration data directly within a graphical asset, a testament to the low-level optimizations employed by the original developers.

| Pixel Coordinate (X, Y) | Controlled UI Element | Description | Source(s) |
| :---- | :---- | :---- | :---- |
| (48, 0\) | Item Background | The background color for listviews, edit boxes, etc. | 16 |
| (50, 0\) | Item Foreground | The text color used within listviews, edit boxes, etc. | 16 |
| (52, 0\) | Window Background | The general background color for the dialog window. | 16 |
| (54, 0\) | Button Text Color | The color of text rendered on standard buttons. | 16 |
| (56, 0\) | Window Text Color | The color of static text labels within the window. | 16 |
| (58, 0\) | Divider/Border Color | The color used for dividers and sunken borders. | 16 |
| (62, 0\) | ListView Header Background | The background color of column headers in a listview. | 16 |
| (64, 0\) | ListView Header Text | The text color of column headers in a listview. | 16 |

## **The Impact of Configuration Files on the Rendering Pipeline**

The rendering process is not solely dictated by the bitmap assets. After the initial composition of the graphical layers, the engine parses several plain text (.txt) files. These files act as a final configuration layer, allowing for stylistic overrides and structural modifications to the rendered output. This reveals a multi-stage rendering pipeline: first, the bitmaps are composited into an off-screen buffer; second, that buffer is modified based on the directives in the text files; and third, a final clipping mask may be applied before the result is drawn to the screen.

### **Color and Font Overrides (viscolor.txt, pledit.txt)**

These files provide fine-grained control over specific visual elements that are not defined by the core bitmaps.

* viscolor.txt contains exactly 24 lines, with each line specifying an RGB color value. These colors are read by the engine to dynamically paint the elements of the built-in music visualization, such as the bars of the spectrum analyzer and the waveform of the oscilloscope.2  
* pledit.txt governs the appearance of the text within the playlist editor. It allows the skinner to specify a Windows font face (e.g., "Arial") and define the colors for normal track text, the currently playing track, and selected items, using standard hexadecimal RGB values (e.g., \#00FF00 for green).11 This overrides the default system font rendering for that specific window.

### **Defining the Visible Canvas (region.txt)**

This is the most powerful and complex of the configuration files, as it allows skinners to break free from the default rectangular shape of the Winamp windows.11 The file is structured with section headers, such as \[Normal\] for the main window and \[Equalizer\] for the EQ window. Within each section, two key-value pairs define the window's shape:

* NumPoints: A comma-separated list of integers. Each integer specifies the number of vertices in a polygon. For example, NumPoints \= 4, 4 defines two separate four-sided polygons.  
* PointList: A single, continuous comma-separated list of X,Y coordinates that define the vertices for all polygons specified in NumPoints.

The engine parses these coordinates and uses them to construct a clipping region, which is effectively a mask. After the entire window has been fully composed in memory as a standard rectangle, this mask is applied. Only the pixels that fall within the boundaries of the defined polygons are ultimately rendered to the screen. All other pixels are discarded, creating the illusion of a transparent background and allowing for skins with unique, non-rectangular shapes.17

## **The Synthesized Rendering Pipeline: A Sequential Model**

By integrating the analysis of the bitmap assets, layering logic, and configuration file overrides, a complete, step-by-step algorithmic model of the rendering process for the main Winamp window can be constructed.

* **Step 1: Skin Loading & Asset Caching:** When a user selects a new skin, Winamp accesses the .wsz archive or the corresponding skin folder. It attempts to load each required .bmp and .txt file into memory. If any specific file is not found, the engine loads its internal default asset for that component instead.7  
* **Step 2: Initialize Off-Screen Buffer:** The engine creates an in-memory bitmap buffer, typically 275 pixels wide by 116 pixels high, which will serve as the canvas for composition.  
* **Step 3: Draw Background (Layer 0):** The entire content of the loaded main.bmp is copied into the off-screen buffer, forming the base layer.  
* **Step 4: Draw Title Bar (Layer 1):** The engine checks the window's current focus state (active or inactive) and selects the appropriate horizontal title bar sprite from titlebar.bmp. This sprite is then drawn over the top portion of the buffer, overwriting the pixels that were previously drawn from main.bmp.7  
* **Step 5: Composite UI Elements (Layer 2):** The engine proceeds to draw the interactive elements in a fixed, hardcoded order. For each element, it determines the correct state (e.g., pressed, un-pressed, on, off) and crops the corresponding sprite from its source bitmap to be drawn onto the buffer. The inferred order is generally structural elements first, followed by interactive controls:  
  * Position Bar (posbar.bmp)  
  * Volume and Balance Sliders (volume.bmp, balance.bmp)  
  * Playback Control Buttons (cbuttons.bmp)  
  * Shuffle and Repeat Toggles (shufrep.bmp)  
  * Status Indicators (monoster.bmp, playpaus.bmp)  
* **Step 6: Render Alphanumeric Displays (Layer 3):** The engine retrieves the current track time and song title. It renders this information not as text but by looking up each required character in the numbers.bmp and text.bmp sprite sheets, cropping the corresponding character-sprite, and drawing it into the correct position in the buffer.  
* **Step 7: Apply Final Clipping Mask:** If a region.txt file exists in the skin, the engine parses the coordinate data under the \[Normal\] section to generate a clipping mask for the main window.  
* **Step 8: Blit to Screen:** The final, fully composed image residing in the off-screen buffer is drawn (blitted) to the screen. If a clipping mask was generated in the previous step, it is applied during this final operation, ensuring that only the pixels within the defined region are made visible.

| Layer (Z-Index) | UI Component | Source Asset(s) | Rendering Logic |
| :---- | :---- | :---- | :---- |
| 0 (Bottom) | Main Window Background | main.bmp | Full bitmap copy to initialize the buffer. |
| 1 | Title Bar & Corner Buttons | titlebar.bmp | State-dependent sprite selection (active/inactive) drawn over the top of main.bmp. |
| 2 | Sliders & Indicators | posbar.bmp, volume.bmp, balance.bmp, monoster.bmp, playpaus.bmp | State-dependent selection of pre-rendered bar images and overlay of slider knobs. |
| 3 | Interactive Buttons | cbuttons.bmp, shufrep.bmp | State-dependent sprite selection based on mouse interaction and toggle status. |
| 4 (Top) | Alphanumeric Displays | numbers.bmp, text.bmp | Assembly of individual character-sprites to form the time and song title. |
| N/A (Post-Processing) | Window Shape | region.txt | Optional clipping mask applied to the final composed buffer before display. |

## **Conclusion: Characteristics of a Legacy Rendering Engine**

### **Summary of Architectural Principles**

The analysis of the classic Winamp skinning process reveals a rendering engine defined by a set of distinct architectural principles, each a product of the software and hardware landscape of its time.

* **Strict Painter's Algorithm:** The engine employs a fixed, back-to-front rendering order with no concept of a dynamic Z-buffer for handling object depth. Visibility is determined solely by the sequence of drawing operations.19  
* **Hardcoded Coordinates:** The layout is entirely rigid, relying on fixed, hardcoded pixel coordinates for the placement of every UI element. This lack of a dynamic layout system is a defining characteristic of the classic skin architecture.2  
* **Sprite Sheet Abstraction:** The engine makes efficient use of bitmaps as sprite sheets to manage the various visual states of interactive UI elements (e.g., normal, pressed, active, inactive). This was a common and resource-efficient method for creating dynamic-feeling interfaces before the widespread adoption of more advanced graphics libraries.2  
* **Hybrid Configuration Model:** Winamp's engine uses a unique and resourceful combination of methods to control the final appearance: direct asset replacement (.bmp files), text-based configuration directives (.txt files), and even embedded pixel data that is read as color values (genex.bmp).

### **Historical Context and Evolution**

The classic Winamp skinning engine stands as a testament to the clever and highly optimized software engineering practices of the late 1990s. It provided an unprecedented level of user customization for a mainstream application, doing so with a system that was efficient enough to run smoothly on the limited hardware of the era. Its inherent limitations—most notably the fixed layout and the lack of true alpha-channel transparency—were the primary drivers for the development of the more flexible, powerful, and complex "Modern" skin engine. This successor, introduced with Winamp3, utilized XML for layout definition and a scripting language for advanced functionality, marking a significant evolutionary step in UI rendering technology from static, imperative systems to dynamic, declarative ones.1 The recent open-sourcing of Winamp's source code in September 2024 presents a future opportunity for developers to validate this reconstructed rendering model against the actual C++ implementation, offering a definitive look into a landmark piece of software history.23

#### **Works cited**

1. \[Lesson 4.1,5,6 updated\]Make your own skins for Winamp 5, accessed October 23, 2025, [https://geek.digit.in/community/threads/lesson-4-1-5-6-updated-make-your-own-skins-for-winamp-5.8577/](https://geek.digit.in/community/threads/lesson-4-1-5-6-updated-make-your-own-skins-for-winamp-5.8577/)  
2. the winamp skin reference \- Swifty's HQ\!, accessed October 23, 2025, [https://swiftyshq.neocities.org/random/wampc/](https://swiftyshq.neocities.org/random/wampc/)  
3. Winamp \- Wikipedia, accessed October 23, 2025, [https://en.wikipedia.org/wiki/Winamp](https://en.wikipedia.org/wiki/Winamp)  
4. Winamp Skin Tutorial Archived, accessed October 23, 2025, [https://winampskins.neocities.org/](https://winampskins.neocities.org/)  
5. Main Window \- Winamp Skin Tutorial, accessed October 23, 2025, [https://winampskins.neocities.org/main](https://winampskins.neocities.org/main)  
6. WACUP/Winamp-Skinning-Archive \- GitHub, accessed October 23, 2025, [https://github.com/WACUP/Winamp-Skinning-Archive](https://github.com/WACUP/Winamp-Skinning-Archive)  
7. Creating Winamp Skins \- bjoreman.com, accessed October 23, 2025, [https://www.bjoreman.com/old/winamp/skins.htm](https://www.bjoreman.com/old/winamp/skins.htm)  
8. WSZ \- Winamp Skin Tutorial, accessed October 23, 2025, [https://winampskins.neocities.org/wsz](https://winampskins.neocities.org/wsz)  
9. Winamp player: now with web components \- Mux, accessed October 23, 2025, [https://www.mux.com/blog/winamp-with-media-chrome-web-components](https://www.mux.com/blog/winamp-with-media-chrome-web-components)  
10. Planning installing but curious if I can change skins with some button clicks : r/winamp, accessed October 23, 2025, [https://www.reddit.com/r/winamp/comments/10h70uo/planning\_installing\_but\_curious\_if\_i\_can\_change/](https://www.reddit.com/r/winamp/comments/10h70uo/planning_installing_but_curious_if_i_can_change/)  
11. Winamp Skins Tutorial, accessed October 23, 2025, [http://www.geocities.ws/phaelicks/tutorskin.html](http://www.geocities.ws/phaelicks/tutorskin.html)  
12. Winamp Skin \- Just Solve the File Format Problem, accessed October 23, 2025, [http://justsolve.archiveteam.org/wiki/Winamp\_Skin](http://justsolve.archiveteam.org/wiki/Winamp_Skin)  
13. Base Skin \- the Winamp Skin Tutorial\!, accessed October 23, 2025, [https://winampskins.neocities.org/base](https://winampskins.neocities.org/base)  
14. Creating Winamp Skins with QuickSkin, accessed October 23, 2025, [http://www.geocities.ws/j\_frankgoa/waskin/waskins.html](http://www.geocities.ws/j_frankgoa/waskin/waskins.html)  
15. Winamp Skin Templates \- ReadMe \- Alpha-II, accessed October 23, 2025, [https://www.alpha-ii.com/Info/Template.html](https://www.alpha-ii.com/Info/Template.html)  
16. Other Windows \- the Winamp Skin Tutorial\!, accessed October 23, 2025, [https://winampskins.neocities.org/twonine](https://winampskins.neocities.org/twonine)  
17. Config \- the Winamp Skin Tutorial\!, accessed October 23, 2025, [https://winampskins.neocities.org/config](https://winampskins.neocities.org/config)  
18. There are usually five (or less) text files in a winamp skin: pledit.txt, readme.txt, region.txt, viscolor.txt and winampmb.txt. Well, the last one is often absent. You can find a detailed description of every file below. \- Hugi, accessed October 23, 2025, [https://www.hugi.scene.org/online/hugi26/hugi%2026%20-%20graphics%20skinning%20sacrat%20winamp%20skinning%20tutorial%20-%204.htm](https://www.hugi.scene.org/online/hugi26/hugi%2026%20-%20graphics%20skinning%20sacrat%20winamp%20skinning%20tutorial%20-%204.htm)  
19. Batching and Z-order with Alpha blending in a 3D world, accessed October 23, 2025, [https://gamedev.stackexchange.com/questions/69835/batching-and-z-order-with-alpha-blending-in-a-3d-world](https://gamedev.stackexchange.com/questions/69835/batching-and-z-order-with-alpha-blending-in-a-3d-world)  
20. Render order and Depth shorting(z-sorting) : r/GraphicsProgramming \- Reddit, accessed October 23, 2025, [https://www.reddit.com/r/GraphicsProgramming/comments/dr9dk5/render\_order\_and\_depth\_shortingzsorting/](https://www.reddit.com/r/GraphicsProgramming/comments/dr9dk5/render_order_and_depth_shortingzsorting/)  
21. Winamp Modern Skins Tutorial | PDF \- Scribd, accessed October 23, 2025, [https://www.scribd.com/doc/254226759/Winamp-Modern-Skins-Tutorial](https://www.scribd.com/doc/254226759/Winamp-Modern-Skins-Tutorial)  
22. Rendering "modern" Winamp skins in the browser \- Hacker News, accessed October 23, 2025, [https://news.ycombinator.com/item?id=42215438](https://news.ycombinator.com/item?id=42215438)  
23. Legendary Media Player Winamp Releases Source Code After 27 Years, accessed October 23, 2025, [https://cyberinsider.com/legendary-media-player-winamp-releases-source-code-after-27-years/](https://cyberinsider.com/legendary-media-player-winamp-releases-source-code-after-27-years/)  
24. Winamp source code released, but developers criticize its restrictive license \- Ghacks.net, accessed October 23, 2025, [https://www.ghacks.net/2024/09/26/winamp-source-code-released-but-developers-criticize-its-restrictive-license/](https://www.ghacks.net/2024/09/26/winamp-source-code-released-but-developers-criticize-its-restrictive-license/)