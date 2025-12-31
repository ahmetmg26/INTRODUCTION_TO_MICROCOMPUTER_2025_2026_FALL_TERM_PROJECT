"""
Home Automation System - Main Application
Unified interface for Board 1 (Air Conditioner) and Board 2 (Curtain Control)

MAIN MENU:
1. Air Conditioner
2. Curtain Control
3. Exit
"""

import tkinter as tk
from tkinter import ttk

# Import the individual board applications
from home_automation import AirConditionerApp, AirConditionerSystemConnection
from curtain_control import CurtainControlApp, CurtainControlSystemConnection


class MainMenuApp:
    """Main Menu Application for Home Automation System"""
    
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Home Automation System")
        self.root.geometry("400x400")
        self.root.configure(bg='#1a1a2e')
        self.root.resizable(False, False)
        
        self._create_styles()
        self._create_ui()
        
        # Store references to sub-windows
        self.ac_window = None
        self.curtain_window = None
    
    def _create_styles(self):
        """Create custom styles for widgets"""
        self.style = ttk.Style()
        self.style.theme_use('clam')
        
        self.style.configure('Title.TLabel', 
                           font=('Segoe UI', 18, 'bold'),
                           foreground='#ff9f43',
                           background='#1a1a2e')
        
        self.style.configure('Menu.TLabel',
                           font=('Segoe UI', 14, 'bold'),
                           foreground='#ffffff',
                           background='#16213e')
    
    def _create_ui(self):
        """Create the main menu interface"""
        # Main container
        main_frame = tk.Frame(self.root, bg='#1a1a2e', padx=30, pady=30)
        main_frame.pack(fill='both', expand=True)
        
        # Title
        title_label = ttk.Label(main_frame, text="🏠 Home Automation", 
                               style='Title.TLabel')
        title_label.pack(pady=(0, 30))
        
        # Menu Frame
        menu_frame = tk.Frame(main_frame, bg='#16213e', padx=20, pady=20)
        menu_frame.pack(fill='x')
        
        # MAIN MENU header
        ttk.Label(menu_frame, text="MAIN MENU", 
                 style='Menu.TLabel').pack(pady=(0, 15))
        
        # 1. Air Conditioner Button
        ac_btn = tk.Button(menu_frame, 
                          text="1. Air Conditioner",
                          command=self._open_air_conditioner,
                          bg='#0f3460', fg='#ffffff',
                          font=('Segoe UI', 12),
                          width=25, height=2,
                          cursor='hand2',
                          anchor='w', padx=15)
        ac_btn.pack(pady=5)
        
        # 2. Curtain Control Button
        curtain_btn = tk.Button(menu_frame, 
                               text="2. Curtain Control",
                               command=self._open_curtain_control,
                               bg='#0f3460', fg='#ffffff',
                               font=('Segoe UI', 12),
                               width=25, height=2,
                               cursor='hand2',
                               anchor='w', padx=15)
        curtain_btn.pack(pady=5)
        
        # 3. Exit Button
        exit_btn = tk.Button(menu_frame, 
                            text="3. Exit",
                            command=self._exit_app,
                            bg='#e74c3c', fg='#ffffff',
                            font=('Segoe UI', 12),
                            width=25, height=2,
                            cursor='hand2',
                            anchor='w', padx=15)
        exit_btn.pack(pady=5)
    
    def _open_air_conditioner(self):
        """Open Air Conditioner control window"""
        # Create new window for Air Conditioner
        if self.ac_window is not None and self.ac_window.winfo_exists():
            self.ac_window.focus()
            return
        
        self.ac_window = tk.Toplevel(self.root)
        self.ac_window.title("Home Automation System - Air Conditioner")
        self.ac_window.geometry("500x680")
        self.ac_window.configure(bg='#1a1a2e')
        self.ac_window.resizable(False, False)
        
        # Create AC interface in the new window
        self._create_ac_interface(self.ac_window)
    
    def _open_curtain_control(self):
        """Open Curtain Control window"""
        # Create new window for Curtain Control
        if self.curtain_window is not None and self.curtain_window.winfo_exists():
            self.curtain_window.focus()
            return
        
        self.curtain_window = tk.Toplevel(self.root)
        self.curtain_window.title("Home Automation System - Curtain Control")
        self.curtain_window.geometry("500x780")
        self.curtain_window.configure(bg='#1a1a2e')
        self.curtain_window.resizable(False, False)
        
        # Create Curtain interface in the new window
        self._create_curtain_interface(self.curtain_window)
    
    def _create_ac_interface(self, window):
        """Create Air Conditioner interface in given window"""
        import serial
        import serial.tools.list_ports
        from tkinter import messagebox
        import threading
        import time
        
        # Connection object
        connection = AirConditionerSystemConnection()
        
        # Main container
        main_frame = tk.Frame(window, bg='#1a1a2e', padx=20, pady=20)
        main_frame.pack(fill='both', expand=True)
        
        # Title
        ttk.Label(main_frame, text="❄️ Air Conditioner", 
                 style='Title.TLabel').pack(pady=(0, 20))
        
        # Data Display Frame
        data_frame = tk.Frame(main_frame, bg='#16213e', padx=20, pady=20)
        data_frame.pack(fill='x', pady=(0, 15))
        
        # Home Ambient Temperature
        ambient_row = tk.Frame(data_frame, bg='#16213e')
        ambient_row.pack(fill='x', pady=5)
        ttk.Label(ambient_row, text="Home Ambient Temperature:", 
                 style='Menu.TLabel').pack(side='left')
        ambient_label = ttk.Label(ambient_row, text="xx.x °C", 
                                 font=('Segoe UI', 14, 'bold'),
                                 foreground='#ff9f43', background='#16213e')
        ambient_label.pack(side='right')
        
        # Home Desired Temperature
        desired_row = tk.Frame(data_frame, bg='#16213e')
        desired_row.pack(fill='x', pady=5)
        ttk.Label(desired_row, text="Home Desired Temperature:", 
                 style='Menu.TLabel').pack(side='left')
        desired_label = ttk.Label(desired_row, text="xx.x °C",
                                 font=('Segoe UI', 14, 'bold'),
                                 foreground='#ff9f43', background='#16213e')
        desired_label.pack(side='right')
        
        # Fan Speed
        fan_row = tk.Frame(data_frame, bg='#16213e')
        fan_row.pack(fill='x', pady=5)
        ttk.Label(fan_row, text="Fan Speed:", 
                 style='Menu.TLabel').pack(side='left')
        fan_label = ttk.Label(fan_row, text="xxx rps",
                             font=('Segoe UI', 14, 'bold'),
                             foreground='#ff9f43', background='#16213e')
        fan_label.pack(side='right')
        
        # Connection Frame
        conn_frame = tk.Frame(main_frame, bg='#16213e', padx=20, pady=15)
        conn_frame.pack(fill='x', pady=(0, 15))
        
        # Port selection
        port_row = tk.Frame(conn_frame, bg='#16213e')
        port_row.pack(fill='x', pady=5)
        ttk.Label(port_row, text="Connection Port:", 
                 style='Menu.TLabel').pack(side='left')
        port_combo = ttk.Combobox(port_row, width=15, state='readonly')
        port_combo.pack(side='right')
        
        # Populate ports
        ports = serial.tools.list_ports.comports()
        port_list = [port.device for port in ports]
        port_combo['values'] = port_list
        if port_list:
            port_combo.set(port_list[0])
        
        # Baudrate
        baud_row = tk.Frame(conn_frame, bg='#16213e')
        baud_row.pack(fill='x', pady=5)
        ttk.Label(baud_row, text="Connection Baudrate:", 
                 style='Menu.TLabel').pack(side='left')
        baud_combo = ttk.Combobox(baud_row, width=15, state='readonly',
                                 values=['9600', '19200', '38400'])
        baud_combo.set('9600')
        baud_combo.pack(side='right')
        
        # Status
        status_label = ttk.Label(main_frame, text="● Disconnected",
                                font=('Segoe UI', 10),
                                foreground='#888888', background='#1a1a2e')
        status_label.pack(pady=5)
        
        # Connect button
        def toggle_connection():
            if connection.is_connected():
                connection.close()
                status_label.configure(text="● Disconnected", foreground='#888888')
                connect_btn.configure(text="Connect", bg='#ff9f43')
            else:
                connection.setComPort(port_combo.get())
                connection.setBaudRate(int(baud_combo.get()))
                if connection.open():
                    status_label.configure(text="● Connected", foreground='#00ff88')
                    connect_btn.configure(text="Disconnect", bg='#ff4444')
                    # Start update thread
                    def update_loop():
                        while connection._is_running:
                            connection.update()
                            window.after(0, lambda: update_display())
                            time.sleep(1.0)
                    threading.Thread(target=update_loop, daemon=True).start()
                else:
                    messagebox.showerror("Error", "Connection failed")
        
        def update_display():
            if connection.is_connected():
                ambient_label.configure(text=f"{connection.getAmbientTemp():.1f} °C")
                desired_label.configure(text=f"{connection.getDesiredTemp():.1f} °C")
                fan_label.configure(text=f"{connection.getFanSpeed()} rps")
        
        connect_btn = tk.Button(main_frame, text="Connect",
                               command=toggle_connection,
                               bg='#ff9f43', fg='#000000',
                               font=('Segoe UI', 11, 'bold'),
                               width=15, cursor='hand2')
        connect_btn.pack(pady=10)
        
        # Menu
        ttk.Label(main_frame, text="MENU", style='Title.TLabel').pack(pady=(10, 10))
        
        menu_frame = tk.Frame(main_frame, bg='#1a1a2e')
        menu_frame.pack(fill='x')
        
        def show_temp_dialog():
            dialog = tk.Toplevel(window)
            dialog.title("Set Temperature")
            dialog.geometry("300x150")
            dialog.configure(bg='#16213e')
            dialog.transient(window)
            dialog.grab_set()
            
            # Center dialog on parent window
            dialog.update_idletasks()
            x = window.winfo_x() + (window.winfo_width() // 2) - 150
            y = window.winfo_y() + (window.winfo_height() // 2) - 75
            dialog.geometry(f"+{x}+{y}")
            
            ttk.Label(dialog, text="Enter Desired Temp:",
                     style='Menu.TLabel').pack(pady=(20, 10))
            entry = tk.Entry(dialog, width=15, font=('Segoe UI', 14),
                           bg='#0f3460', fg='#ffffff', justify='center')
            entry.pack(pady=5)
            entry.focus()
            
            def set_temp():
                try:
                    temp = float(entry.get())
                    if 10 <= temp <= 50:
                        if connection.is_connected():
                            if connection.setDesiredTemp(temp):
                                dialog.destroy()
                                messagebox.showinfo("Success", f"Temperature set to {temp}°C")
                            else:
                                messagebox.showerror("Error", "Failed")
                        else:
                            messagebox.showwarning("Warning", "Not connected")
                    else:
                        messagebox.showerror("Error", "Must be 10-50°C")
                except ValueError:
                    messagebox.showerror("Error", "Invalid number")
            
            tk.Button(dialog, text="Set", command=set_temp,
                     bg='#ff9f43', fg='#000000', width=10).pack(pady=10)
        
        tk.Button(menu_frame, text="1. Enter the desired temperature",
                 command=show_temp_dialog,
                 bg='#0f3460', fg='#ffffff', font=('Segoe UI', 11),
                 width=30, anchor='w', padx=10).pack(pady=5)
        
        tk.Button(menu_frame, text="2. Return",
                 command=lambda: [connection.close(), window.destroy()],
                 bg='#0f3460', fg='#ffffff', font=('Segoe UI', 11),
                 width=30, height=2, anchor='w', padx=10).pack(pady=5)
    
    def _create_curtain_interface(self, window):
        """Create Curtain Control interface in given window"""
        import serial
        import serial.tools.list_ports
        from tkinter import messagebox
        import threading
        import time
        
        # Connection object
        connection = CurtainControlSystemConnection()
        
        # Main container
        main_frame = tk.Frame(window, bg='#1a1a2e', padx=20, pady=20)
        main_frame.pack(fill='both', expand=True)
        
        # Title
        ttk.Label(main_frame, text="🪟 Curtain Control", 
                 style='Title.TLabel').pack(pady=(0, 20))
        
        # Data Display Frame
        data_frame = tk.Frame(main_frame, bg='#16213e', padx=20, pady=20)
        data_frame.pack(fill='x', pady=(0, 15))
        
        # Outdoor Temperature
        temp_row = tk.Frame(data_frame, bg='#16213e')
        temp_row.pack(fill='x', pady=5)
        ttk.Label(temp_row, text="Outdoor Temperature:", 
                 style='Menu.TLabel').pack(side='left')
        temp_label = ttk.Label(temp_row, text="xx.x °C",
                              font=('Segoe UI', 14, 'bold'),
                              foreground='#ff9f43', background='#16213e')
        temp_label.pack(side='right')
        
        # Outdoor Pressure
        press_row = tk.Frame(data_frame, bg='#16213e')
        press_row.pack(fill='x', pady=5)
        ttk.Label(press_row, text="Outdoor Pressure:", 
                 style='Menu.TLabel').pack(side='left')
        press_label = ttk.Label(press_row, text="xxxx.x hPa",
                               font=('Segoe UI', 14, 'bold'),
                               foreground='#ff9f43', background='#16213e')
        press_label.pack(side='right')
        
        # Curtain Status
        curtain_row = tk.Frame(data_frame, bg='#16213e')
        curtain_row.pack(fill='x', pady=5)
        ttk.Label(curtain_row, text="Curtain Status:", 
                 style='Menu.TLabel').pack(side='left')
        curtain_label = ttk.Label(curtain_row, text="xx.x %",
                                 font=('Segoe UI', 14, 'bold'),
                                 foreground='#ff9f43', background='#16213e')
        curtain_label.pack(side='right')
        
        # Light Intensity
        light_row = tk.Frame(data_frame, bg='#16213e')
        light_row.pack(fill='x', pady=5)
        ttk.Label(light_row, text="Light Intensity:", 
                 style='Menu.TLabel').pack(side='left')
        light_label = ttk.Label(light_row, text="xxx.x Lux",
                               font=('Segoe UI', 14, 'bold'),
                               foreground='#ff9f43', background='#16213e')
        light_label.pack(side='right')
        
        # Connection Frame
        conn_frame = tk.Frame(main_frame, bg='#16213e', padx=20, pady=15)
        conn_frame.pack(fill='x', pady=(0, 15))
        
        # Port selection
        port_row = tk.Frame(conn_frame, bg='#16213e')
        port_row.pack(fill='x', pady=5)
        ttk.Label(port_row, text="Connection Port:", 
                 style='Menu.TLabel').pack(side='left')
        port_combo = ttk.Combobox(port_row, width=15, state='readonly')
        port_combo.pack(side='right')
        
        # Populate ports
        ports = serial.tools.list_ports.comports()
        port_list = [port.device for port in ports]
        port_combo['values'] = port_list
        if port_list:
            port_combo.set(port_list[0])
        
        # Baudrate
        baud_row = tk.Frame(conn_frame, bg='#16213e')
        baud_row.pack(fill='x', pady=5)
        ttk.Label(baud_row, text="Connection Baudrate:", 
                 style='Menu.TLabel').pack(side='left')
        baud_combo = ttk.Combobox(baud_row, width=15, state='readonly',
                                 values=['9600', '19200', '38400'])
        baud_combo.set('9600')
        baud_combo.pack(side='right')
        
        # Status
        status_label = ttk.Label(main_frame, text="● Disconnected",
                                font=('Segoe UI', 10),
                                foreground='#888888', background='#1a1a2e')
        status_label.pack(pady=5)
        
        # Connect button
        def toggle_connection():
            if connection.is_connected():
                connection.close()
                status_label.configure(text="● Disconnected", foreground='#888888')
                connect_btn.configure(text="Connect", bg='#ff9f43')
            else:
                connection.setComPort(port_combo.get())
                connection.setBaudRate(int(baud_combo.get()))
                if connection.open():
                    status_label.configure(text="● Connected", foreground='#00ff88')
                    connect_btn.configure(text="Disconnect", bg='#ff4444')
                    # Start update thread
                    def update_loop():
                        while connection._is_running:
                            connection.update()
                            window.after(0, lambda: update_display())
                            time.sleep(1.0)
                    threading.Thread(target=update_loop, daemon=True).start()
                else:
                    messagebox.showerror("Error", "Connection failed")
        
        def update_display():
            if connection.is_connected():
                temp_label.configure(text=f"{connection.getOutdoorTemp():.1f} °C")
                press_label.configure(text=f"{connection.getOutdoorPress():.1f} hPa")
                curtain_label.configure(text=f"{connection.getCurtainStatus():.1f} %")
                light_label.configure(text=f"{connection.getLightIntensity():.1f} Lux")
        
        connect_btn = tk.Button(main_frame, text="Connect",
                               command=toggle_connection,
                               bg='#ff9f43', fg='#000000',
                               font=('Segoe UI', 11, 'bold'),
                               width=15, cursor='hand2')
        connect_btn.pack(pady=10)
        
        # Menu
        ttk.Label(main_frame, text="MENU", style='Title.TLabel').pack(pady=(10, 10))
        
        menu_frame = tk.Frame(main_frame, bg='#1a1a2e')
        menu_frame.pack(fill='x')
        
        def show_curtain_dialog():
            dialog = tk.Toplevel(window)
            dialog.title("Set Curtain Status")
            dialog.geometry("300x150")
            dialog.configure(bg='#16213e')
            dialog.transient(window)
            dialog.grab_set()
            
            # Center dialog on parent window
            dialog.update_idletasks()
            x = window.winfo_x() + (window.winfo_width() // 2) - 150
            y = window.winfo_y() + (window.winfo_height() // 2) - 75
            dialog.geometry(f"+{x}+{y}")
            
            ttk.Label(dialog, text="Enter Desired Curtain:",
                     style='Menu.TLabel').pack(pady=(20, 10))
            entry = tk.Entry(dialog, width=15, font=('Segoe UI', 14),
                           bg='#0f3460', fg='#ffffff', justify='center')
            entry.pack(pady=5)
            entry.focus()
            
            def set_curtain():
                try:
                    pos = float(entry.get())
                    if 0 <= pos <= 100:
                        if connection.is_connected():
                            if connection.setCurtainStatus(pos):
                                dialog.destroy()
                                messagebox.showinfo("Success", f"Curtain set to {pos}%")
                            else:
                                messagebox.showerror("Error", "Failed")
                        else:
                            messagebox.showwarning("Warning", "Not connected")
                    else:
                        messagebox.showerror("Error", "Must be 0-100%")
                except ValueError:
                    messagebox.showerror("Error", "Invalid number")
            
            tk.Button(dialog, text="Set", command=set_curtain,
                     bg='#ff9f43', fg='#000000', width=10).pack(pady=10)
        
        tk.Button(menu_frame, text="1. Enter the desired curtain status",
                 command=show_curtain_dialog,
                 bg='#0f3460', fg='#ffffff', font=('Segoe UI', 11),
                 width=30, anchor='w', padx=10).pack(pady=5)
        
        tk.Button(menu_frame, text="2. Return",
                 command=lambda: [connection.close(), window.destroy()],
                 bg='#0f3460', fg='#ffffff', font=('Segoe UI', 11),
                 width=30, height=2, anchor='w', padx=10).pack(pady=5)
    
    def _exit_app(self):
        """Exit the application"""
        self.root.quit()
    
    def run(self):
        """Start the application"""
        self.root.protocol("WM_DELETE_WINDOW", self._exit_app)
        self.root.mainloop()


def main():
    """Main entry point"""
    app = MainMenuApp()
    app.run()


if __name__ == "__main__":
    main()
