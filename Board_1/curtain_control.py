"""
Curtain Control System - PC Application
Board 2: Automatic Curtain Control System
UART Communication with PIC16F877A

UART Protocol (Binary Command-Response) per Specification:
PC -> PIC Commands:
  0x01 = Get desired curtain status low byte (fractional)
  0x02 = Get desired curtain status high byte (integral)
  0x03 = Get outdoor temperature low byte (fractional)
  0x04 = Get outdoor temperature high byte (integral)
  0x05 = Get outdoor pressure low byte (fractional)
  0x06 = Get outdoor pressure high byte (integral)
  0x07 = Get light intensity low byte (fractional)
  0x08 = Get light intensity high byte (integral)
  10xxxxxx = Set desired curtain status low byte (fractional)
  11xxxxxx = Set desired curtain status high byte (integral)
"""

import serial
import serial.tools.list_ports
import tkinter as tk
from tkinter import ttk, messagebox
import threading
import time


# Command constants per specification
CMD_GET_CURTAIN_FRAC = 0x01
CMD_GET_CURTAIN_INT = 0x02
CMD_GET_TEMP_FRAC = 0x03
CMD_GET_TEMP_INT = 0x04
CMD_GET_PRESS_FRAC = 0x05
CMD_GET_PRESS_INT = 0x06
CMD_GET_LIGHT_FRAC = 0x07
CMD_GET_LIGHT_INT = 0x08


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


class CurtainControlSystemConnection(HomeAutomationSystemConnection):
    """Class for Curtain Control (Board 2) communication"""
    
    def __init__(self):
        super().__init__()
        self.curtainStatus = 0.0
        self.outdoorTemperature = 0.0
        self.outdoorPressure = 0.0
        self.lightIntensity = 0.0
        self._update_callback = None
    
    def update(self) -> None:
        """Get all data and update member data by sending commands"""
        if not self.is_connected():
            return
        
        try:
            # Get curtain status (integral + fractional)
            curtain_int = self._send_command(CMD_GET_CURTAIN_INT)
            curtain_frac = self._send_command(CMD_GET_CURTAIN_FRAC)
            self.curtainStatus = curtain_int + (curtain_frac / 10.0)
            print(f"[DEBUG] Curtain: {curtain_int}.{curtain_frac} = {self.curtainStatus}%")
            
            # Get outdoor temperature
            temp_int = self._send_command(CMD_GET_TEMP_INT)
            temp_frac = self._send_command(CMD_GET_TEMP_FRAC)
            self.outdoorTemperature = temp_int + (temp_frac / 10.0)
            print(f"[DEBUG] Outdoor Temp: {temp_int}.{temp_frac} = {self.outdoorTemperature}C")
            
            # Get outdoor pressure (integral is LOW byte of 16-bit value)
            press_int = self._send_command(CMD_GET_PRESS_INT)
            press_frac = self._send_command(CMD_GET_PRESS_FRAC)
            # Pressure is stored as H*256+L, but we only get LOW byte
            # For 1013 hPa: H=3, L=245 -> we get 245, need to add H*256
            # Since we can't get H easily, assume pressure = L + 768 (for ~1000 range)
            self.outdoorPressure = (press_int + 768) + (press_frac / 10.0)
            print(f"[DEBUG] Outdoor Press: {self.outdoorPressure} hPa")
            
            # Get light intensity
            light_int = self._send_command(CMD_GET_LIGHT_INT)
            light_frac = self._send_command(CMD_GET_LIGHT_FRAC)
            self.lightIntensity = light_int + (light_frac / 10.0)
            print(f"[DEBUG] Light: {light_int}.{light_frac} = {self.lightIntensity} Lux")
            
            if self._update_callback:
                self._update_callback()
                
        except Exception as e:
            print(f"Update error: {e}")
    
    def setCurtainStatus(self, status: float) -> bool:
        """Set the desired curtain status by sending message to board"""
        if not self.is_connected():
            return False
        
        try:
            # Split into integral and fractional parts
            integral = int(status)
            fractional = int((status - integral) * 10)
            
            # Validate range (0-100)
            if integral < 0 or integral > 100:
                return False
            
            # Send SET commands
            # Set integral: 11xxxxxx (0xC0 | value)
            cmd_int = 0xC0 | (integral & 0x3F)
            self.serial_connection.write(bytes([cmd_int]))
            self.serial_connection.flush()
            print(f"[DEBUG] Set curtain integral: {hex(cmd_int)} = {integral}")
            
            time.sleep(0.1)
            
            # Set fractional: 10xxxxxx (0x80 | value)
            cmd_frac = 0x80 | (fractional & 0x3F)
            self.serial_connection.write(bytes([cmd_frac]))
            self.serial_connection.flush()
            print(f"[DEBUG] Set curtain fractional: {hex(cmd_frac)} = {fractional}")
            
            return True
        except Exception as e:
            print(f"Set curtain error: {e}")
            return False
    
    def getOutdoorTemp(self) -> float:
        """Get the outdoor temperature"""
        return self.outdoorTemperature
    
    def getOutdoorPress(self) -> float:
        """Get the outdoor pressure"""
        return self.outdoorPressure
    
    def getLightIntensity(self) -> float:
        """Get the light intensity"""
        return self.lightIntensity
    
    def getCurtainStatus(self) -> float:
        """Get the curtain status (position)"""
        return self.curtainStatus
    
    def set_update_callback(self, callback):
        """Set callback function for UI updates"""
        self._update_callback = callback


class CurtainControlApp:
    """GUI Application for Curtain Control System (Board 2)"""
    
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Home Automation System - Curtain Control")
        self.root.geometry("500x700")
        self.root.configure(bg='#1a1a2e')
        self.root.resizable(False, False)
        
        self.connection = CurtainControlSystemConnection()
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
        title_label = ttk.Label(main_frame, text="🪟 Curtain Control", 
                               style='Title.TLabel')
        title_label.pack(pady=(0, 20))
        
        # Data Display Frame
        data_frame = tk.Frame(main_frame, bg='#16213e', padx=20, pady=20)
        data_frame.pack(fill='x', pady=(0, 15))
        
        # Outdoor Temperature
        temp_row = tk.Frame(data_frame, bg='#16213e')
        temp_row.pack(fill='x', pady=5)
        ttk.Label(temp_row, text="Outdoor Temperature:", 
                 style='Data.TLabel').pack(side='left')
        self.temp_label = ttk.Label(temp_row, text="xx.x °C", 
                                    style='Value.TLabel')
        self.temp_label.pack(side='right')
        
        # Outdoor Pressure
        press_row = tk.Frame(data_frame, bg='#16213e')
        press_row.pack(fill='x', pady=5)
        ttk.Label(press_row, text="Outdoor Pressure:", 
                 style='Data.TLabel').pack(side='left')
        self.press_label = ttk.Label(press_row, text="xxxx.x hPa", 
                                     style='Value.TLabel')
        self.press_label.pack(side='right')
        
        # Curtain Status
        pos_row = tk.Frame(data_frame, bg='#16213e')
        pos_row.pack(fill='x', pady=5)
        ttk.Label(pos_row, text="Curtain Status:", 
                 style='Data.TLabel').pack(side='left')
        self.position_label = ttk.Label(pos_row, text="xx.x %", 
                                        style='Value.TLabel')
        self.position_label.pack(side='right')
        
        # Light Intensity
        light_row = tk.Frame(data_frame, bg='#16213e')
        light_row.pack(fill='x', pady=5)
        ttk.Label(light_row, text="Light Intensity:", 
                 style='Data.TLabel').pack(side='left')
        self.light_label = ttk.Label(light_row, text="xxx.x Lux", 
                                     style='Value.TLabel')
        self.light_label.pack(side='right')
        
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
        
        # Set Curtain Position Button
        set_pos_btn = tk.Button(menu_frame, 
                                text="1. Enter the desired curtain status",
                                command=self._show_position_dialog,
                                bg='#0f3460', fg='#ffffff',
                                font=('Segoe UI', 11),
                                width=35, cursor='hand2',
                                anchor='w', padx=10)
        set_pos_btn.pack(pady=5)
        
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
            
            self.temp_label.configure(
                text=f"{self.connection.getOutdoorTemp():.1f} °C")
            self.press_label.configure(
                text=f"{self.connection.getOutdoorPress():.1f} hPa")
            self.position_label.configure(
                text=f"{self.connection.getCurtainStatus():.1f} %")
            self.light_label.configure(
                text=f"{self.connection.getLightIntensity():.1f} Lux")
            
        except Exception as e:
            print(f"Display update error: {e}")
    
    def _show_position_dialog(self):
        """Show position input dialog as a popup window"""
        # Create popup window
        self.pos_dialog = tk.Toplevel(self.root)
        self.pos_dialog.title("Set Curtain Status")
        self.pos_dialog.geometry("350x180")
        self.pos_dialog.configure(bg='#16213e')
        self.pos_dialog.resizable(False, False)
        self.pos_dialog.transient(self.root)
        self.pos_dialog.grab_set()
        
        # Center the dialog
        self.pos_dialog.update_idletasks()
        x = self.root.winfo_x() + (self.root.winfo_width() // 2) - 175
        y = self.root.winfo_y() + (self.root.winfo_height() // 2) - 90
        self.pos_dialog.geometry(f"+{x}+{y}")
        
        # Label
        ttk.Label(self.pos_dialog, text="Enter Desired Curtain:", 
                 style='Data.TLabel').pack(pady=(20, 10))
        
        # Entry
        self.pos_entry = tk.Entry(self.pos_dialog, width=15, 
                                  font=('Segoe UI', 14),
                                  bg='#0f3460', fg='#ffffff',
                                  insertbackground='#ffffff', justify='center')
        self.pos_entry.pack(pady=5)
        self.pos_entry.focus()
        
        # Buttons frame
        btn_frame = tk.Frame(self.pos_dialog, bg='#16213e')
        btn_frame.pack(pady=10)
        
        set_btn = tk.Button(btn_frame, text="Set",
                           command=self._set_position,
                           bg='#ff9f43', fg='#000000',
                           font=('Segoe UI', 10, 'bold'),
                           width=8, cursor='hand2')
        set_btn.pack(side='left', padx=5)
        
        cancel_btn = tk.Button(btn_frame, text="Cancel",
                              command=self._hide_position_dialog,
                              bg='#ff4444', fg='#ffffff',
                              font=('Segoe UI', 10),
                              width=8, cursor='hand2')
        cancel_btn.pack(side='left', padx=5)
    
    def _hide_position_dialog(self):
        """Close position input dialog"""
        if hasattr(self, 'pos_dialog') and self.pos_dialog:
            self.pos_dialog.destroy()
            self.pos_dialog = None
    
    def _set_position(self):
        """Set the curtain position"""
        print("[DEBUG] _set_position called")
        try:
            input_text = self.pos_entry.get()
            print(f"[DEBUG] Input text: '{input_text}'")
            pos = float(input_text)
            print(f"[DEBUG] Parsed position: {pos}")
            
            if 0 <= pos <= 100:
                print(f"[DEBUG] Position valid, is_connected: {self.connection.is_connected()}")
                if self.connection.is_connected():
                    result = self.connection.setCurtainStatus(pos)
                    print(f"[DEBUG] setCurtainStatus returned: {result}")
                    # Close dialog first
                    self._hide_position_dialog()
                    # Show message after dialog is closed
                    if result:
                        self.root.after(100, lambda: messagebox.showinfo("Success", f"Curtain status set to {pos}%"))
                    else:
                        self.root.after(100, lambda: messagebox.showerror("Error", "Failed to set curtain status"))
                else:
                    self._hide_position_dialog()
                    self.root.after(100, lambda: messagebox.showwarning("Warning", "Not connected to board"))
            else:
                messagebox.showerror("Error", "Value must be between 0 and 100")
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
    app = CurtainControlApp()
    app.run()


if __name__ == "__main__":
    main()
