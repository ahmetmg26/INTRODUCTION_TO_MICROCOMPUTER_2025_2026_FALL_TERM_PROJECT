"""
Home Automation System - PC Application
Board 1: Air Conditioner Control System
UART Communication with PIC16F877A

UART Protocol (Binary Command-Response) per Specification:
PC -> PIC Commands:
  0x01 = Get desired temp fractional
  0x02 = Get desired temp integral
  0x03 = Get ambient temp fractional
  0x04 = Get ambient temp integral
  0x05 = Get fan speed
  10xxxxxx = Set desired temp fractional (6-bit value)
  11xxxxxx = Set desired temp integral (6-bit value)
"""

import serial
import serial.tools.list_ports
import tkinter as tk
from tkinter import ttk, messagebox
import threading
import time


# Command constants per specification
CMD_GET_DESIRED_FRAC = 0x01
CMD_GET_DESIRED_INT = 0x02
CMD_GET_AMBIENT_FRAC = 0x03
CMD_GET_AMBIENT_INT = 0x04
CMD_GET_FAN_SPEED = 0x05


class HomeAutomationSystemConnection:
    """Base class for serial communication with boards"""
    
    def __init__(self):
        self.comPort = None
        self.baudRate = 9600
        self.serial_connection = None
        self._is_running = False
    
    def open(self) -> bool:
        """Initiate connection to the Board via UART port"""
        try:
            if self.comPort is None:
                return False
            print(f"[DEBUG] Opening {self.comPort} at {self.baudRate} baud")
            self.serial_connection = serial.Serial(
                port=self.comPort,
                baudrate=self.baudRate,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE,
                timeout=0.1
            )
            self.serial_connection.reset_input_buffer()
            self.serial_connection.reset_output_buffer()
            self._is_running = True
            return True
        except serial.SerialException as e:
            print(f"Connection error: {e}")
            return False
    
    def close(self) -> bool:
        """Closes the connection to the board"""
        try:
            self._is_running = False
            if self.serial_connection and self.serial_connection.is_open:
                self.serial_connection.close()
            return True
        except Exception as e:
            print(f"Close error: {e}")
            return False
    
    def setComPort(self, port: int) -> None:
        """Set the communication port number"""
        if isinstance(port, int):
            self.comPort = f"COM{port}"
        else:
            self.comPort = port
    
    def setBaudRate(self, rate: int) -> None:
        """Set the communication baudrate"""
        self.baudRate = rate
    
    def is_connected(self) -> bool:
        """Check if connection is active"""
        return self.serial_connection is not None and self.serial_connection.is_open
    
    def _send_command(self, cmd: int) -> int:
        """Send a command byte and receive response"""
        if not self.is_connected():
            return 0
        
        try:
            self.serial_connection.write(bytes([cmd]))
            response = self.serial_connection.read(1)
            if response:
                return response[0]
            return 0
        except Exception as e:
            print(f"Command error: {e}")
            return 0


class AirConditionerSystemConnection(HomeAutomationSystemConnection):
    """Class for Air Conditioner (Board 1) communication"""
    
    def __init__(self):
        super().__init__()
        self.desiredTemperature = 0.0
        self.ambientTemperature = 0.0
        self.fanSpeed = 0
        self._update_callback = None
    
    def update(self) -> None:
        """Get all data and update member data by sending commands"""
        if not self.is_connected():
            return
        
        try:
            # Get desired temperature
            desired_int = self._send_command(CMD_GET_DESIRED_INT)
            desired_frac = self._send_command(CMD_GET_DESIRED_FRAC)
            self.desiredTemperature = desired_int + (desired_frac / 10.0)
            print(f"[DEBUG] Desired Temp: {desired_int}.{desired_frac} = {self.desiredTemperature}C")
            
            # Get ambient temperature
            ambient_int = self._send_command(CMD_GET_AMBIENT_INT)
            ambient_frac = self._send_command(CMD_GET_AMBIENT_FRAC)
            self.ambientTemperature = ambient_int + (ambient_frac / 10.0)
            print(f"[DEBUG] Ambient Temp: {ambient_int}.{ambient_frac} = {self.ambientTemperature}C")
            
            # Get fan speed
            raw_fan = self._send_command(CMD_GET_FAN_SPEED)
            self.fanSpeed = raw_fan
            print(f"[DEBUG] Fan Speed: {self.fanSpeed} rps")
            
            if self._update_callback:
                self._update_callback()
                
        except Exception as e:
            print(f"Update error: {e}")
    
    def setDesiredTemp(self, temp: float) -> bool:
        """Set the desired temperature by sending message to board"""
        if not self.is_connected():
            return False
        
        try:
            # Split into integral and fractional parts
            integral = int(temp)
            fractional = int((temp - integral) * 10)
            
            # Validate range
            if integral < 0 or integral > 63:
                return False
            
            # Send SET commands per specification
            # Set integral: 11xxxxxx (0xC0 | value)
            cmd_int = 0xC0 | (integral & 0x3F)
            self.serial_connection.write(bytes([cmd_int]))
            self.serial_connection.flush()
            print(f"[DEBUG] Set temp integral: {hex(cmd_int)} = {integral}")
            
            time.sleep(0.1)
            
            # Set fractional: 10xxxxxx (0x80 | value)
            cmd_frac = 0x80 | (fractional & 0x3F)
            self.serial_connection.write(bytes([cmd_frac]))
            self.serial_connection.flush()
            print(f"[DEBUG] Set temp fractional: {hex(cmd_frac)} = {fractional}")
            
            return True
        except Exception as e:
            print(f"Set temp error: {e}")
            return False
    
    def getAmbientTemp(self) -> float:
        """Get the ambient temperature"""
        return self.ambientTemperature
    
    def getFanSpeed(self) -> int:
        """Get the fan speed"""
        return self.fanSpeed
    
    def getDesiredTemp(self) -> float:
        """Get the desired temperature"""
        return self.desiredTemperature
    
    def set_update_callback(self, callback):
        """Set callback function for UI updates"""
        self._update_callback = callback


class AirConditionerApp:
    """GUI Application for Air Conditioner System (Board 1)"""
    
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Home Automation System - Air Conditioner")
        self.root.geometry("500x600")
        self.root.configure(bg='#1a1a2e')
        self.root.resizable(False, False)
        
        self.connection = AirConditionerSystemConnection()
        self.connection.set_update_callback(self._update_display)
        
        self._update_thread = None
        self._create_styles()
        self._create_ui()
        self._populate_ports()
    
    def _create_styles(self):
        """Create custom styles for widgets"""
        self.style = ttk.Style()
        self.style.theme_use('clam')
        
        self.style.configure('Title.TLabel', 
                           font=('Segoe UI', 16, 'bold'),
                           foreground='#ff9f43',
                           background='#1a1a2e')
        
        self.style.configure('Data.TLabel',
                           font=('Segoe UI', 12),
                           foreground='#ffffff',
                           background='#16213e')
        
        self.style.configure('Value.TLabel',
                           font=('Segoe UI', 14, 'bold'),
                           foreground='#ff9f43',
                           background='#16213e')
        
        self.style.configure('Status.TLabel',
                           font=('Segoe UI', 10),
                           foreground='#888888',
                           background='#1a1a2e')
    
    def _create_ui(self):
        """Create the user interface"""
        # Main container
        main_frame = tk.Frame(self.root, bg='#1a1a2e', padx=20, pady=20)
        main_frame.pack(fill='both', expand=True)
        
        # Title
        title_label = ttk.Label(main_frame, text="❄️ Air Conditioner", 
                               style='Title.TLabel')
        title_label.pack(pady=(0, 20))
        
        # Data Display Frame
        data_frame = tk.Frame(main_frame, bg='#16213e', padx=20, pady=20)
        data_frame.pack(fill='x', pady=(0, 15))
        
        # Home Ambient Temperature
        ambient_row = tk.Frame(data_frame, bg='#16213e')
        ambient_row.pack(fill='x', pady=5)
        ttk.Label(ambient_row, text="Home Ambient Temperature:", 
                 style='Data.TLabel').pack(side='left')
        self.ambient_label = ttk.Label(ambient_row, text="xx.x °C", 
                                       style='Value.TLabel')
        self.ambient_label.pack(side='right')
        
        # Home Desired Temperature
        desired_row = tk.Frame(data_frame, bg='#16213e')
        desired_row.pack(fill='x', pady=5)
        ttk.Label(desired_row, text="Home Desired Temperature:", 
                 style='Data.TLabel').pack(side='left')
        self.desired_label = ttk.Label(desired_row, text="xx.x °C", 
                                       style='Value.TLabel')
        self.desired_label.pack(side='right')
        
        # Fan Speed
        fan_row = tk.Frame(data_frame, bg='#16213e')
        fan_row.pack(fill='x', pady=5)
        ttk.Label(fan_row, text="Fan Speed:", 
                 style='Data.TLabel').pack(side='left')
        self.fan_label = ttk.Label(fan_row, text="xxx rps", 
                                   style='Value.TLabel')
        self.fan_label.pack(side='right')
        
        # Separator
        separator = tk.Frame(main_frame, bg='#333355', height=2)
        separator.pack(fill='x', pady=10)
        
        # Connection Frame
        conn_frame = tk.Frame(main_frame, bg='#16213e', padx=20, pady=15)
        conn_frame.pack(fill='x', pady=(0, 15))
        
        # Port selection
        port_row = tk.Frame(conn_frame, bg='#16213e')
        port_row.pack(fill='x', pady=5)
        ttk.Label(port_row, text="Connection Port:", 
                 style='Data.TLabel').pack(side='left')
        self.port_combo = ttk.Combobox(port_row, width=15, state='readonly')
        self.port_combo.pack(side='right')
        
        # Baudrate
        baud_row = tk.Frame(conn_frame, bg='#16213e')
        baud_row.pack(fill='x', pady=5)
        ttk.Label(baud_row, text="Connection Baudrate:", 
                 style='Data.TLabel').pack(side='left')
        self.baud_combo = ttk.Combobox(baud_row, width=15, state='readonly',
                                       values=['9600', '19200', '38400', '57600', '115200'])
        self.baud_combo.set('9600')
        self.baud_combo.pack(side='right')
        
        # Connection status
        self.status_label = ttk.Label(main_frame, text="● Disconnected", 
                                      style='Status.TLabel')
        self.status_label.pack(pady=5)
        
        # Connection buttons
        btn_frame = tk.Frame(main_frame, bg='#1a1a2e')
        btn_frame.pack(pady=10)
        
        self.connect_btn = tk.Button(btn_frame, text="Connect", 
                                     command=self._toggle_connection,
                                     bg='#ff9f43', fg='#000000',
                                     font=('Segoe UI', 11, 'bold'),
                                     width=12, cursor='hand2')
        self.connect_btn.pack(side='left', padx=5)
        
        refresh_btn = tk.Button(btn_frame, text="↻ Refresh Ports", 
                               command=self._populate_ports,
                               bg='#333355', fg='#ffffff',
                               font=('Segoe UI', 10),
                               cursor='hand2')
        refresh_btn.pack(side='left', padx=5)
        
        # Separator
        separator2 = tk.Frame(main_frame, bg='#333355', height=2)
        separator2.pack(fill='x', pady=10)
        
        # Menu Frame
        menu_label = ttk.Label(main_frame, text="MENU", style='Title.TLabel')
        menu_label.pack(pady=(5, 10))
        
        menu_frame = tk.Frame(main_frame, bg='#1a1a2e')
        menu_frame.pack(fill='x')
        
        # Enter desired temperature Button
        set_temp_btn = tk.Button(menu_frame, 
                                text="1. Enter the desired temperature",
                                command=self._show_temp_dialog,
                                bg='#0f3460', fg='#ffffff',
                                font=('Segoe UI', 11),
                                width=35, cursor='hand2',
                                anchor='w', padx=10)
        set_temp_btn.pack(pady=5)
        
        # Return/Exit Button
        exit_btn = tk.Button(menu_frame, text="2. Return",
                            command=self._exit_app,
                            bg='#0f3460', fg='#ffffff',
                            font=('Segoe UI', 11),
                            width=35, cursor='hand2',
                            anchor='w', padx=10)
        exit_btn.pack(pady=5)
    
    def _populate_ports(self):
        """Get available COM ports"""
        ports = serial.tools.list_ports.comports()
        port_list = [port.device for port in ports]
        self.port_combo['values'] = port_list
        if port_list:
            self.port_combo.set(port_list[0])
    
    def _toggle_connection(self):
        """Connect or disconnect from the board"""
        if self.connection.is_connected():
            self._disconnect()
        else:
            self._connect()
    
    def _connect(self):
        """Establish connection to board"""
        port = self.port_combo.get()
        if not port:
            messagebox.showerror("Error", "Please select a COM port")
            return
        
        self.connection.setComPort(port)
        self.connection.setBaudRate(int(self.baud_combo.get()))
        
        if self.connection.open():
            self.status_label.configure(text="● Connected", foreground='#00ff88')
            self.connect_btn.configure(text="Disconnect", bg='#ff4444')
            self._start_update_thread()
        else:
            messagebox.showerror("Error", f"Failed to connect to {port}")
    
    def _disconnect(self):
        """Close connection to board"""
        self.connection.close()
        self.status_label.configure(text="● Disconnected", foreground='#888888')
        self.connect_btn.configure(text="Connect", bg='#ff9f43')
    
    def _start_update_thread(self):
        """Start background thread for reading serial data"""
        def update_loop():
            while self.connection._is_running:
                self.connection.update()
                time.sleep(1.0)
        
        self._update_thread = threading.Thread(target=update_loop, daemon=True)
        self._update_thread.start()
    
    def _update_display(self):
        """Update the display with current values"""
        try:
            self.root.after(0, self._do_update_display)
        except Exception as e:
            print(f"Display callback error: {e}")
    
    def _do_update_display(self):
        """Actually update the display (runs in main thread)"""
        try:
            if not self.connection.is_connected():
                return
            
            self.ambient_label.configure(
                text=f"{self.connection.getAmbientTemp():.1f} °C")
            self.desired_label.configure(
                text=f"{self.connection.getDesiredTemp():.1f} °C")
            self.fan_label.configure(
                text=f"{self.connection.getFanSpeed()} rps")
            
        except Exception as e:
            print(f"Display update error: {e}")
    
    def _show_temp_dialog(self):
        """Show temperature input dialog as a popup window"""
        # Create popup window
        self.temp_dialog = tk.Toplevel(self.root)
        self.temp_dialog.title("Set Temperature")
        self.temp_dialog.geometry("350x180")
        self.temp_dialog.configure(bg='#16213e')
        self.temp_dialog.resizable(False, False)
        self.temp_dialog.transient(self.root)
        self.temp_dialog.grab_set()
        
        # Center the dialog
        self.temp_dialog.update_idletasks()
        x = self.root.winfo_x() + (self.root.winfo_width() // 2) - 175
        y = self.root.winfo_y() + (self.root.winfo_height() // 2) - 90
        self.temp_dialog.geometry(f"+{x}+{y}")
        
        # Label
        ttk.Label(self.temp_dialog, text="Enter Desired Temp:", 
                 style='Data.TLabel').pack(pady=(20, 10))
        
        # Entry
        self.temp_entry = tk.Entry(self.temp_dialog, width=15, 
                                   font=('Segoe UI', 14),
                                   bg='#0f3460', fg='#ffffff',
                                   insertbackground='#ffffff', justify='center')
        self.temp_entry.pack(pady=5)
        self.temp_entry.focus()
        
        # Buttons frame
        btn_frame = tk.Frame(self.temp_dialog, bg='#16213e')
        btn_frame.pack(pady=10)
        
        set_btn = tk.Button(btn_frame, text="Set",
                           command=self._set_temperature,
                           bg='#ff9f43', fg='#000000',
                           font=('Segoe UI', 10, 'bold'),
                           width=8, cursor='hand2')
        set_btn.pack(side='left', padx=5)
        
        cancel_btn = tk.Button(btn_frame, text="Cancel",
                              command=self._hide_temp_dialog,
                              bg='#ff4444', fg='#ffffff',
                              font=('Segoe UI', 10),
                              width=8, cursor='hand2')
        cancel_btn.pack(side='left', padx=5)
    
    def _hide_temp_dialog(self):
        """Close temperature input dialog"""
        if hasattr(self, 'temp_dialog') and self.temp_dialog:
            self.temp_dialog.destroy()
            self.temp_dialog = None
    
    def _set_temperature(self):
        """Set the desired temperature"""
        print("[DEBUG] _set_temperature called")
        try:
            input_text = self.temp_entry.get()
            print(f"[DEBUG] Input text: '{input_text}'")
            temp = float(input_text)
            print(f"[DEBUG] Parsed temperature: {temp}")
            
            if 10 <= temp <= 50:
                print(f"[DEBUG] Temperature valid, is_connected: {self.connection.is_connected()}")
                if self.connection.is_connected():
                    result = self.connection.setDesiredTemp(temp)
                    print(f"[DEBUG] setDesiredTemp returned: {result}")
                    self._hide_temp_dialog()
                    if result:
                        self.root.after(100, lambda: messagebox.showinfo("Success", f"Temperature set to {temp}°C"))
                    else:
                        self.root.after(100, lambda: messagebox.showerror("Error", "Failed to set temperature"))
                else:
                    self._hide_temp_dialog()
                    self.root.after(100, lambda: messagebox.showwarning("Warning", "Not connected to board"))
            else:
                messagebox.showerror("Error", "Temperature must be between 10 and 50°C")
        except ValueError as e:
            print(f"[DEBUG] ValueError: {e}")
            messagebox.showerror("Error", "Please enter a valid number")
    
    def _exit_app(self):
        """Exit the application"""
        if self.connection.is_connected():
            self.connection.close()
        self.root.quit()
    
    def run(self):
        """Start the application"""
        self.root.protocol("WM_DELETE_WINDOW", self._exit_app)
        self.root.mainloop()


def main():
    """Main entry point"""
    app = AirConditionerApp()
    app.run()


if __name__ == "__main__":
    main()
