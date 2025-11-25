"""
Sensors Panel for KlipperScreen
Display angle sensor and hall counter status
"""
import gi
import logging

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, GLib

from ks_includes.screen_panel import ScreenPanel


class Panel(ScreenPanel):
    """Sensor status display panel"""
    
    def __init__(self, screen, title):
        super().__init__(screen, title)
        
        # Update timer
        self.update_timer = None
        
        # Create UI
        self.create_ui()
    
    def create_ui(self):
        """Build the sensors panel UI"""
        grid = Gtk.Grid()
        grid.set_row_spacing(15)
        grid.set_column_spacing(20)
        grid.set_margin_start(20)
        grid.set_margin_end(20)
        grid.set_margin_top(20)
        grid.set_margin_bottom(20)
        
        # Title
        title = Gtk.Label()
        title.set_markup("<span size='x-large' weight='bold'>Sensor Status</span>")
        title.set_hexpand(True)
        grid.attach(title, 0, 0, 2, 1)
        
        # Angle Sensor Section
        angle_title = Gtk.Label()
        angle_title.set_markup("<span size='large' weight='bold'>Angle Sensor</span>")
        angle_title.set_halign(Gtk.Align.START)
        angle_title.set_margin_top(10)
        grid.attach(angle_title, 0, 1, 2, 1)
        
        # Angle value
        angle_label = Gtk.Label()
        angle_label.set_markup("<span size='medium'>Current Angle:</span>")
        angle_label.set_halign(Gtk.Align.START)
        grid.attach(angle_label, 0, 2, 1, 1)
        
        self.angle_value = Gtk.Label()
        self.angle_value.set_markup("<span size='xx-large' weight='bold' foreground='#4CAF50'>0.0°</span>")
        self.angle_value.set_halign(Gtk.Align.END)
        grid.attach(self.angle_value, 1, 2, 1, 1)
        
        # Turn count
        turns_label = Gtk.Label()
        turns_label.set_markup("<span size='medium'>Turn Count:</span>")
        turns_label.set_halign(Gtk.Align.START)
        grid.attach(turns_label, 0, 3, 1, 1)
        
        self.turns_value = Gtk.Label()
        self.turns_value.set_markup("<span size='large' weight='bold'>0</span>")
        self.turns_value.set_halign(Gtk.Align.END)
        grid.attach(self.turns_value, 1, 3, 1, 1)
        
        # ADC range
        adc_label = Gtk.Label()
        adc_label.set_markup("<span size='medium'>ADC Range:</span>")
        adc_label.set_halign(Gtk.Align.START)
        grid.attach(adc_label, 0, 4, 1, 1)
        
        self.adc_value = Gtk.Label()
        self.adc_value.set_markup("<span size='medium'>Not calibrated</span>")
        self.adc_value.set_halign(Gtk.Align.END)
        grid.attach(self.adc_value, 1, 4, 1, 1)
        
        # Separator
        separator = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        separator.set_margin_top(10)
        separator.set_margin_bottom(10)
        grid.attach(separator, 0, 5, 2, 1)
        
        # Hall Sensor Section
        hall_title = Gtk.Label()
        hall_title.set_markup("<span size='large' weight='bold'>Hall Sensor</span>")
        hall_title.set_halign(Gtk.Align.START)
        grid.attach(hall_title, 0, 6, 2, 1)
        
        # Hall count
        hall_count_label = Gtk.Label()
        hall_count_label.set_markup("<span size='medium'>Pulse Count:</span>")
        hall_count_label.set_halign(Gtk.Align.START)
        grid.attach(hall_count_label, 0, 7, 1, 1)
        
        self.hall_count_value = Gtk.Label()
        self.hall_count_value.set_markup("<span size='xx-large' weight='bold' foreground='#2196F3'>0</span>")
        self.hall_count_value.set_halign(Gtk.Align.END)
        grid.attach(self.hall_count_value, 1, 7, 1, 1)
        
        # Hall RPM
        hall_rpm_label = Gtk.Label()
        hall_rpm_label.set_markup("<span size='medium'>Spindle RPM:</span>")
        hall_rpm_label.set_halign(Gtk.Align.START)
        grid.attach(hall_rpm_label, 0, 8, 1, 1)
        
        self.hall_rpm_value = Gtk.Label()
        self.hall_rpm_value.set_markup("<span size='large' weight='bold'>0</span>")
        self.hall_rpm_value.set_halign(Gtk.Align.END)
        grid.attach(self.hall_rpm_value, 1, 8, 1, 1)
        
        # Separator
        separator2 = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        separator2.set_margin_top(10)
        separator2.set_margin_bottom(10)
        grid.attach(separator2, 0, 9, 2, 1)
        
        # Refresh button
        refresh_btn = self._gtk.Button("refresh", "Refresh", "color2", 1)
        refresh_btn.connect("clicked", self.refresh_sensors)
        grid.attach(refresh_btn, 0, 10, 2, 1)
        
        # Last update time
        self.update_time_label = Gtk.Label()
        self.update_time_label.set_markup("<span size='small'>Never updated</span>")
        self.update_time_label.set_margin_top(10)
        grid.attach(self.update_time_label, 0, 11, 2, 1)
        
        self.content.add(grid)
    
    def refresh_sensors(self, widget=None):
        """Query and update sensor values"""
        import time
        
        # Query angle sensor
        try:
            # This would query the actual sensor status from Klipper
            # For now, using placeholder
            self._screen._ws.klippy.gcode_script("QUERY_ANGLE_SENSOR")
            self._screen._ws.klippy.gcode_script("QUERY_HW_COUNTER")
            
            # Update timestamp
            current_time = time.strftime("%H:%M:%S")
            self.update_time_label.set_markup(f"<span size='small'>Last update: {current_time}</span>")
        except Exception as e:
            logging.error(f"Error refreshing sensors: {e}")
    
    def update_display(self, data):
        """Update display with sensor data"""
        # This would be called when sensor data is received
        # Update angle sensor
        if 'angle_sensor' in data:
            angle = data['angle_sensor'].get('angle', 0)
            turns = data['angle_sensor'].get('turn_count', 0)
            adc_min = data['angle_sensor'].get('adc_min', 0)
            adc_max = data['angle_sensor'].get('adc_max', 0)
            
            self.angle_value.set_markup(f"<span size='xx-large' weight='bold' foreground='#4CAF50'>{angle:.1f}°</span>")
            self.turns_value.set_markup(f"<span size='large' weight='bold'>{turns}</span>")
            
            if adc_min and adc_max:
                self.adc_value.set_markup(f"<span size='medium'>{adc_min:.3f} - {adc_max:.3f}</span>")
        
        # Update hall sensor
        if 'hw_counter' in data:
            count = data['hw_counter'].get('count', 0)
            rpm = data['hw_counter'].get('rpm', 0)
            
            self.hall_count_value.set_markup(f"<span size='xx-large' weight='bold' foreground='#2196F3'>{count}</span>")
            self.hall_rpm_value.set_markup(f"<span size='large' weight='bold'>{rpm:.1f}</span>")
    
    def activate(self):
        """Called when panel becomes active"""
        # Start auto-refresh timer (update every 2 seconds)
        if self.update_timer is None:
            self.update_timer = GLib.timeout_add_seconds(2, self.auto_refresh)
        self.refresh_sensors()
    
    def deactivate(self):
        """Called when panel becomes inactive"""
        # Stop auto-refresh timer
        if self.update_timer is not None:
            GLib.source_remove(self.update_timer)
            self.update_timer = None
    
    def auto_refresh(self):
        """Auto-refresh callback"""
        self.refresh_sensors()
        return True  # Continue timer

