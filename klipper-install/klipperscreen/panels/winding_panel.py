"""
Winding Panel for KlipperScreen
Custom panel for coil winding operations
"""
import gi
import logging

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Pango

from ks_includes.screen_panel import ScreenPanel


class Panel(ScreenPanel):
    """Main winding control panel"""
    
    def __init__(self, screen, title):
        super().__init__(screen, title)
        
        # Winding parameters
        self.rpm = 300
        self.layers = 10
        self.is_winding = False
        
        # Create UI
        self.create_ui()
    
    def create_ui(self):
        """Build the winding panel UI"""
        grid = Gtk.Grid()
        grid.set_row_spacing(10)
        grid.set_column_spacing(10)
        grid.set_margin_start(20)
        grid.set_margin_end(20)
        grid.set_margin_top(20)
        grid.set_margin_bottom(20)
        
        # Title
        title = Gtk.Label()
        title.set_markup("<span size='x-large' weight='bold'>Winding Control</span>")
        title.set_hexpand(True)
        grid.attach(title, 0, 0, 4, 1)
        
        # RPM Control
        rpm_label = Gtk.Label()
        rpm_label.set_markup("<span size='large'>RPM:</span>")
        rpm_label.set_halign(Gtk.Align.START)
        grid.attach(rpm_label, 0, 1, 1, 1)
        
        self.rpm_value = Gtk.Label()
        self.rpm_value.set_markup(f"<span size='xx-large' weight='bold'>{self.rpm}</span>")
        grid.attach(self.rpm_value, 1, 1, 1, 1)
        
        rpm_minus = self._gtk.Button("decrease", None, "color1", 1)
        rpm_minus.connect("clicked", self.adjust_rpm, -50)
        grid.attach(rpm_minus, 2, 1, 1, 1)
        
        rpm_plus = self._gtk.Button("increase", None, "color2", 1)
        rpm_plus.connect("clicked", self.adjust_rpm, 50)
        grid.attach(rpm_plus, 3, 1, 1, 1)
        
        # Layers Control
        layers_label = Gtk.Label()
        layers_label.set_markup("<span size='large'>Layers:</span>")
        layers_label.set_halign(Gtk.Align.START)
        grid.attach(layers_label, 0, 2, 1, 1)
        
        self.layers_value = Gtk.Label()
        self.layers_value.set_markup(f"<span size='xx-large' weight='bold'>{self.layers}</span>")
        grid.attach(self.layers_value, 1, 2, 1, 1)
        
        layers_minus = self._gtk.Button("decrease", None, "color1", 1)
        layers_minus.connect("clicked", self.adjust_layers, -1)
        grid.attach(layers_minus, 2, 2, 1, 1)
        
        layers_plus = self._gtk.Button("increase", None, "color2", 1)
        layers_plus.connect("clicked", self.adjust_layers, 1)
        grid.attach(layers_plus, 3, 2, 1, 1)
        
        # Separator
        separator = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        separator.set_margin_top(10)
        separator.set_margin_bottom(10)
        grid.attach(separator, 0, 3, 4, 1)
        
        # Quick preset buttons
        preset_label = Gtk.Label()
        preset_label.set_markup("<span size='medium'>Quick Presets:</span>")
        preset_label.set_halign(Gtk.Align.START)
        grid.attach(preset_label, 0, 4, 4, 1)
        
        preset_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        
        test_btn = self._gtk.Button("test", "Test\n100 RPM\n1 Layer", "color3", 1)
        test_btn.connect("clicked", self.load_preset, 100, 1)
        preset_box.pack_start(test_btn, True, True, 0)
        
        low_btn = self._gtk.Button("speed-step", "Low Speed\n200 RPM\n10 Layers", "color3", 1)
        low_btn.connect("clicked", self.load_preset, 200, 10)
        preset_box.pack_start(low_btn, True, True, 0)
        
        med_btn = self._gtk.Button("speed-step", "Medium\n300 RPM\n20 Layers", "color3", 1)
        med_btn.connect("clicked", self.load_preset, 300, 20)
        preset_box.pack_start(med_btn, True, True, 0)
        
        high_btn = self._gtk.Button("speed-step", "High Speed\n500 RPM\n30 Layers", "color3", 1)
        high_btn.connect("clicked", self.load_preset, 500, 30)
        preset_box.pack_start(high_btn, True, True, 0)
        
        grid.attach(preset_box, 0, 5, 4, 1)
        
        # Separator
        separator2 = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        separator2.set_margin_top(10)
        separator2.set_margin_bottom(10)
        grid.attach(separator2, 0, 6, 4, 1)
        
        # Control buttons
        button_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=20)
        button_box.set_halign(Gtk.Align.CENTER)
        
        self.home_btn = self._gtk.Button("home", "Home &\nCalibrate", "color1", 1.5)
        self.home_btn.connect("clicked", self.home_and_calibrate)
        button_box.pack_start(self.home_btn, True, True, 0)
        
        self.start_btn = self._gtk.Button("arrow-right", "Start\nWinding", "color2", 1.5)
        self.start_btn.connect("clicked", self.start_winding)
        button_box.pack_start(self.start_btn, True, True, 0)
        
        self.stop_btn = self._gtk.Button("stop", "Stop\nWinding", "color4", 1.5)
        self.stop_btn.connect("clicked", self.stop_winding)
        self.stop_btn.set_sensitive(False)
        button_box.pack_start(self.stop_btn, True, True, 0)
        
        grid.attach(button_box, 0, 7, 4, 1)
        
        # Status display
        self.status_label = Gtk.Label()
        self.status_label.set_markup("<span size='medium'>Ready</span>")
        self.status_label.set_margin_top(20)
        grid.attach(self.status_label, 0, 8, 4, 1)
        
        self.content.add(grid)
    
    def adjust_rpm(self, widget, delta):
        """Adjust RPM value"""
        self.rpm = max(10, min(3300, self.rpm + delta))
        self.rpm_value.set_markup(f"<span size='xx-large' weight='bold'>{self.rpm}</span>")
    
    def adjust_layers(self, widget, delta):
        """Adjust layers value"""
        self.layers = max(1, min(100, self.layers + delta))
        self.layers_value.set_markup(f"<span size='xx-large' weight='bold'>{self.layers}</span>")
    
    def load_preset(self, widget, rpm, layers):
        """Load preset values"""
        self.rpm = rpm
        self.layers = layers
        self.rpm_value.set_markup(f"<span size='xx-large' weight='bold'>{self.rpm}</span>")
        self.layers_value.set_markup(f"<span size='xx-large' weight='bold'>{self.layers}</span>")
        self.status_label.set_markup(f"<span size='medium'>Loaded: {rpm} RPM, {layers} layers</span>")
    
    def home_and_calibrate(self, widget):
        """Home traverse and calibrate spindle"""
        self.status_label.set_markup("<span size='medium' foreground='yellow'>Homing and calibrating...</span>")
        self._screen._ws.klippy.gcode_script("HOME_TRAVERSE")
        self.status_label.set_markup("<span size='medium' foreground='green'>Calibration complete</span>")
    
    def start_winding(self, widget):
        """Start winding operation"""
        self.is_winding = True
        self.start_btn.set_sensitive(False)
        self.stop_btn.set_sensitive(True)
        self.home_btn.set_sensitive(False)
        
        self.status_label.set_markup(f"<span size='medium' foreground='green'>Winding: {self.rpm} RPM, {self.layers} layers</span>")
        
        script = f"WINDER_START RPM={self.rpm} LAYERS={self.layers}"
        self._screen._ws.klippy.gcode_script(script)
    
    def stop_winding(self, widget):
        """Stop winding operation"""
        self.is_winding = False
        self.start_btn.set_sensitive(True)
        self.stop_btn.set_sensitive(False)
        self.home_btn.set_sensitive(True)
        
        self.status_label.set_markup("<span size='medium' foreground='red'>Stopping...</span>")
        self._screen._ws.klippy.gcode_script("WINDER_STOP")
        
        self.status_label.set_markup("<span size='medium'>Stopped</span>")
    
    def activate(self):
        """Called when panel becomes active"""
        pass
    
    def deactivate(self):
        """Called when panel becomes inactive"""
        pass

