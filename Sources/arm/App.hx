package arm;

import zui.Zui;
import zui.Zui.Handle;
import zui.Canvas;
import arm.ui.UITrait;
import arm.ui.UINodes;
import arm.ui.UIView2D;
import arm.ui.UIMenu;
import arm.ui.UIBox;
import arm.ui.UIFiles;
import arm.Config;
import kha.graphics2.truetype.StbTruetype;

class App extends iron.Trait {

	public static var version = "0.6";
	public static function x():Int { return appx; }
	public static function y():Int { return appy; }
	static var appx = 0;
	static var appy = 0;
	public static var uienabled = true;
	public static var isDragging = false;
	public static var dragMaterial:MaterialSlot = null;
	public static var dragAsset:TAsset = null;
	public static var dragOffX = 0.0;
	public static var dragOffY = 0.0;
	public static var showFiles = false;
	public static var showBox = false;
	public static var foldersOnly = false;
	public static var showFilename = false;
	public static var whandle = new Handle();
	public static var filenameHandle = new Handle({text: "untitled"});
	public static var filesDone:String->Void;
	public static var dropPath = "";
	public static var dropX = 0.0;
	public static var dropY = 0.0;
	public static var font:kha.Font = null;
	public static var theme:zui.Themes.TTheme;
	public static var color_wheel:kha.Image;
	public static var uibox:Zui;
	public static var path = '/';
	public static var showMenu = false;
	public static var fileArg = "";

	public static var C:TConfig; // Config
	public static var K:Dynamic; // Config.Keymap

	public function new() {
		super();

		// Restore default config
		if (!armory.data.Config.configLoaded) {
			var C = armory.data.Config.raw;
			C.rp_bloom = true;
			C.rp_gi = false;
			C.rp_motionblur = false;
			C.rp_shadowmap_cube = 0;
			C.rp_shadowmap_cascade = 0;
			C.rp_ssgi = true;
			C.rp_ssr = false;
			C.rp_supersample = 1.0;
		}

		// Init config
		C = Config.init();
		K = C.keymap;

		#if arm_resizable
		iron.App.onResize = onResize;
		#end

		// Set base dir for file browser
		zui.Ext.dataPath = iron.data.Data.dataPath;

		kha.System.notifyOnDropFiles(function(filePath:String) {
			dropPath = filePath;
			dropPath = StringTools.replace(dropPath, "%20", " "); // Linux can pass %20 on drop
			dropPath = dropPath.split("file://")[0]; // Multiple files dropped on Linux, take first
			dropPath = StringTools.rtrim(dropPath);
		});

		iron.data.Data.getFont("font_default.ttf", function(f:kha.Font) {
			iron.data.Data.getBlob("themes/theme_dark.arm", function(b:kha.Blob) {
				iron.data.Data.getImage('color_wheel.png', function(image:kha.Image) {
					font = f;

					#if kha_krom // Pre-baked font texture
					var kimg:kha.Kravur.KravurImage = js.Object.create(untyped kha.Kravur.KravurImage.prototype);
					@:privateAccess kimg.mySize = 13;
					@:privateAccess kimg.width = 128;
					@:privateAccess kimg.height = 128;
					@:privateAccess kimg.baseline = 10;
					var chars = new haxe.ds.Vector(ConstData.font_x0.length);
					// kha.graphics2.Graphics.fontGlyphs = [for (i in 32...127) i];
					kha.graphics2.Graphics.fontGlyphs = [for (i in 32...206) i]; // Fix tiny font
					// for (i in 0...ConstData.font_x0.length) chars[i] = new Stbtt_bakedchar();
					for (i in 0...174) chars[i] = new Stbtt_bakedchar();
					for (i in 0...ConstData.font_x0.length) chars[i].x0 = ConstData.font_x0[i];
					for (i in 0...ConstData.font_y0.length) chars[i].y0 = ConstData.font_y0[i];
					for (i in 0...ConstData.font_x1.length) chars[i].x1 = ConstData.font_x1[i];
					for (i in 0...ConstData.font_y1.length) chars[i].y1 = ConstData.font_y1[i];
					for (i in 0...ConstData.font_xoff.length) chars[i].xoff = ConstData.font_xoff[i];
					for (i in 0...ConstData.font_yoff.length) chars[i].yoff = ConstData.font_yoff[i];
					for (i in 0...ConstData.font_xadvance.length) chars[i].xadvance = ConstData.font_xadvance[i];
					@:privateAccess kimg.chars = chars;
					iron.data.Data.getBlob("font13.bin", function(fontbin:kha.Blob) {
						@:privateAccess kimg.texture = kha.Image.fromBytes(fontbin.toBytes(), 128, 128, kha.graphics4.TextureFormat.L8);
						// @:privateAccess cast(font, kha.Kravur).images.set(130095, kimg);
						@:privateAccess cast(font, kha.Kravur).images.set(130174, kimg);
					});
					#end

					parseTheme(b);
					color_wheel = image;
					zui.Nodes.getEnumTexts = getEnumTexts;
					zui.Nodes.mapEnum = mapEnum;
					Zui.alwaysRedrawWindow = false;
					uibox = new Zui({ font: f, scaleFactor: armory.data.Config.raw.window_scale });
					
					iron.App.notifyOnInit(function() {
						// File to open passed as argument
						#if kha_krom
						if (Krom.getArgCount() > 1) {
							var path = Krom.getArg(1);
							if (Format.checkProjectFormat(path) ||
								Format.checkMeshFormat(path) ||
								Format.checkTextureFormat(path) ||
								Format.checkFontFormat(path)) {
								fileArg = path;
							}
						}
						#end
						iron.App.notifyOnUpdate(update);
						var root = iron.Scene.active.root;
						root.addTrait(new UITrait());
						root.addTrait(new UINodes());
						root.addTrait(new UIView2D());
						root.addTrait(new arm.trait.FlyCamera());
						root.addTrait(new arm.trait.OrbitCamera());
						root.addTrait(new arm.trait.RotateCamera());
						iron.App.notifyOnRender2D(@:privateAccess UITrait.inst.renderCursor);
						iron.App.notifyOnUpdate(@:privateAccess UINodes.inst.update);
						iron.App.notifyOnRender2D(@:privateAccess UINodes.inst.render);
						iron.App.notifyOnUpdate(@:privateAccess UITrait.inst.update);
						iron.App.notifyOnRender2D(@:privateAccess UITrait.inst.render);
						iron.App.notifyOnRender2D(render);
						appx = C.ui_layout == 0 ? UITrait.inst.toolbarw : UITrait.inst.windowW + UITrait.inst.toolbarw;
						appy = UITrait.inst.headerh * 2;
						var cam = iron.Scene.active.camera;
						cam.data.raw.fov = Std.int(cam.data.raw.fov * 100) / 100;
						cam.buildProjection();
						if (fileArg != "") {
							Importer.importFile(fileArg);
							if (Format.checkMeshFormat(fileArg)) {
								UITrait.inst.toggleDistractFree();
							}
							else if (Format.checkTextureFormat(fileArg)) {
								UITrait.inst.show2DView(1);
							}
							// fileArg = "";
						}
					});
				});
			});
		});
	}

	public static function parseTheme(b:kha.Blob) {
		theme = haxe.Json.parse(b.toString());
		theme.WINDOW_BG_COL = Std.parseInt(cast theme.WINDOW_BG_COL);
		theme.WINDOW_TINT_COL = Std.parseInt(cast theme.WINDOW_TINT_COL);
		theme.ACCENT_COL = Std.parseInt(cast theme.ACCENT_COL);
		theme.ACCENT_HOVER_COL = Std.parseInt(cast theme.ACCENT_HOVER_COL);
		theme.ACCENT_SELECT_COL = Std.parseInt(cast theme.ACCENT_SELECT_COL);
		theme.PANEL_BG_COL = Std.parseInt(cast theme.PANEL_BG_COL);
		theme.PANEL_TEXT_COL = Std.parseInt(cast theme.PANEL_TEXT_COL);
		theme.BUTTON_COL = Std.parseInt(cast theme.BUTTON_COL);
		theme.BUTTON_TEXT_COL = Std.parseInt(cast theme.BUTTON_TEXT_COL);
		theme.BUTTON_HOVER_COL = Std.parseInt(cast theme.BUTTON_HOVER_COL);
		theme.BUTTON_PRESSED_COL = Std.parseInt(cast theme.BUTTON_PRESSED_COL);
		theme.TEXT_COL = Std.parseInt(cast theme.TEXT_COL);
		theme.LABEL_COL = Std.parseInt(cast theme.LABEL_COL);
		theme.ARROW_COL = Std.parseInt(cast theme.ARROW_COL);
		theme.SEPARATOR_COL = Std.parseInt(cast theme.SEPARATOR_COL);
	}

	public static function w():Int {
		// Draw material preview
		if (UITrait.inst != null && UITrait.inst.materialPreview) return arm.util.RenderUtil.matPreviewSize;

		// Drawing decal preview
		if (UITrait.inst != null && UITrait.inst.decalPreview) return arm.util.RenderUtil.decalPreviewSize;
		
		var res = 0;
		if (UINodes.inst == null || UITrait.inst == null) {
			res = kha.System.windowWidth() - UITrait.defaultWindowW;
			res -= UITrait.defaultToolbarW;
		}
		else if (UINodes.inst.show || UIView2D.inst.show) {
			res = Std.int((kha.System.windowWidth() - UITrait.inst.windowW) / 2);
			res -= UITrait.inst.toolbarw;
		}
		else if (UITrait.inst.show) {
			res = kha.System.windowWidth() - UITrait.inst.windowW;
			res -= UITrait.inst.toolbarw;
		}
		else {
			res = kha.System.windowWidth();
		}

		return res > 0 ? res : 1; // App was minimized, force render path resize
	}

	public static function h():Int {
		// Draw material preview
		if (UITrait.inst != null && UITrait.inst.materialPreview) return arm.util.RenderUtil.matPreviewSize;

		// Drawing decal preview
		if (UITrait.inst != null && UITrait.inst.decalPreview) return arm.util.RenderUtil.decalPreviewSize;

		var res = 0;
		res = kha.System.windowHeight();
		if (UITrait.inst == null) res -= UITrait.defaultHeaderH * 3;
		if (UITrait.inst != null && UITrait.inst.show && res > 0) res -= UITrait.inst.headerh * 3;

		return res > 0 ? res : 1; // App was minimized, force render path resize
	}

	#if arm_resizable
	static function onResize() {
		resize();
		
		// Save window size
		// C.window_w = kha.System.windowWidth();
		// C.window_h = kha.System.windowHeight();
		// Cap height, window is not centered properly
		// var disp =  kha.Display.primary;
		// if (disp.height > 0 && C.window_h > disp.height - 140) {
		// 	C.window_h = disp.height - 140;
		// }
		// armory.data.Config.save();
	}
	#end

	public static function resize() {
		if (kha.System.windowWidth() == 0 || kha.System.windowHeight() == 0) return;

		var cam = iron.Scene.active.camera;
		if (cam.data.raw.ortho != null) {
			cam.data.raw.ortho[2] = -2 * (iron.App.h() / iron.App.w());
			cam.data.raw.ortho[3] =  2 * (iron.App.h() / iron.App.w());
		}
		cam.buildProjection();
		UITrait.inst.ddirty = 2;

		var lay = C.ui_layout;
		
		appx = lay == 0 ? UITrait.inst.toolbarw : UITrait.inst.windowW + UITrait.inst.toolbarw;
		if (lay == 1 && (UINodes.inst.show || UIView2D.inst.show)) {
			appx += iron.App.w() + UITrait.inst.toolbarw;
		}

		appy = UITrait.inst.headerh * 2;

		if (!UITrait.inst.show) {
			appx = 0;
			appy = 0;
		}

		if (UINodes.inst.grid != null) {
			UINodes.inst.grid.unload();
			UINodes.inst.grid = null;
		}

		UITrait.inst.hwnd.redraws = 2;
		UITrait.inst.hwnd1.redraws = 2;
		UITrait.inst.hwnd2.redraws = 2;
		UITrait.inst.headerHandle.redraws = 2;
		UITrait.inst.toolbarHandle.redraws = 2;
		UITrait.inst.statusHandle.redraws = 2;
		UITrait.inst.menuHandle.redraws = 2;
		UITrait.inst.workspaceHandle.redraws = 2;
	}

	static function update() {
		var mouse = iron.system.Input.getMouse();
		var kb = iron.system.Input.getKeyboard();

		if ((dragAsset != null || dragMaterial != null) &&
			(mouse.movementX != 0 || mouse.movementY != 0)) {
			isDragging = true;
		}
		if (mouse.released()) {
			var x = mouse.x + iron.App.x();
			var y = mouse.y + iron.App.y();
			if (dragAsset != null) {
				// Texture dragged onto node canvas
				if (UINodes.inst.show && x > UINodes.inst.wx && y > UINodes.inst.wy) {
					var index = 0;
					for (i in 0...UITrait.inst.assets.length) {
						if (UITrait.inst.assets[i] == dragAsset) {
							index = i;
							break;
						}
					}
					// Create image texture
					UINodes.inst.acceptDrag(index);
				}
				dragAsset = null;
			}
			if (dragMaterial != null) {
				// Material dragged onto viewport or layers tab
				var inViewport = UITrait.inst.paintVec.x < 1 && UITrait.inst.paintVec.x > 0 &&
								 UITrait.inst.paintVec.y < 1 && UITrait.inst.paintVec.y > 0;
				var inLayers = UITrait.inst.htab.position == 0 &&
							   mouse.x > UITrait.inst.tabx && mouse.y < UITrait.inst.tabh;
				if (inViewport || inLayers) {
					// Create fill layer
					var l = UITrait.inst.newLayer();
					UITrait.inst.toFillLayer(l);
				}
				dragMaterial = null;
			}
			isDragging = false;
		}

		if (dropPath != "") {
			var wait = kha.System.systemId == "Linux" && !mouse.moved; // Mouse coords not updated on Linux during drag
			if (!wait) {
				dropX = mouse.x + App.x();
				dropY = mouse.y + App.y();
				Importer.importFile(dropPath, dropX, dropY);
				dropPath = "";
			}
		}

		if (showFiles || showBox) UIBox.update();
	}

	static function render(g:kha.graphics2.Graphics) {
		if (kha.System.windowWidth() == 0 || kha.System.windowHeight() == 0) return;

		var mouse = iron.system.Input.getMouse();
		if (isDragging) {
			var img = dragAsset != null ? UITrait.inst.getImage(dragAsset) : dragMaterial.imageIcon;
			@:privateAccess var size = 50 * UITrait.inst.ui.SCALE;
			var ratio = size / img.width;
			var h = img.height * ratio;
			g.drawScaledImage(img, mouse.x + iron.App.x() + dragOffX, mouse.y + iron.App.y() + dragOffY, size, h);
		}

		var usingMenu = false;
		if (showMenu) usingMenu = mouse.y + App.y() > UITrait.inst.headerh;

		uienabled = !showFiles && !showBox && !usingMenu;
		if (showFiles) UIFiles.render(g);
		else if (showBox) UIBox.render(g);
		else if (showMenu) UIMenu.render(g);
	}

	public static function getEnumTexts():Array<String> {
		return UITrait.inst.assetNames.length > 0 ? UITrait.inst.assetNames : [""];
	}

	public static function mapEnum(s:String):String {
		for (a in UITrait.inst.assets) if (a.name == s) return a.file;
		return "";
	}

	public static function getAssetIndex(f:String):Int {
		for (i in 0...UITrait.inst.assets.length) {
			if (UITrait.inst.assets[i].file == f) {
				return i;
			}
		}
		return 0;
	}
}
