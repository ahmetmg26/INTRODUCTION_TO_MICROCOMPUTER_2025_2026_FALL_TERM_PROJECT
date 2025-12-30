"""
Test Program for Home Automation System Connection Classes
[R2.3-2] Tests each member function of classes

Tests for:
- HomeAutomationSystemConnection (base class)
- AirConditionerSystemConnection (Board 1)
- CurtainControlSystemConnection (Board 2)
"""

import unittest
from unittest.mock import Mock, patch, MagicMock
import sys
import os

# Import the classes to test
from home_automation import AirConditionerSystemConnection
from curtain_control import CurtainControlSystemConnection


class TestAirConditionerSystemConnection(unittest.TestCase):
    """Test cases for AirConditionerSystemConnection class"""
    
    def setUp(self):
        """Set up test fixtures"""
        self.connection = AirConditionerSystemConnection()
    
    def tearDown(self):
        """Clean up after tests"""
        if self.connection.is_connected():
            self.connection.close()
    
    # ==================== setComPort() Tests ====================
    def test_setComPort_with_integer(self):
        """Test setComPort with integer port number"""
        self.connection.setComPort(3)
        self.assertEqual(self.connection.comPort, "COM3")
    
    def test_setComPort_with_string(self):
        """Test setComPort with string port name"""
        self.connection.setComPort("COM8")
        self.assertEqual(self.connection.comPort, "COM8")
    
    # ==================== setBaudRate() Tests ====================
    def test_setBaudRate_9600(self):
        """Test setBaudRate with 9600"""
        self.connection.setBaudRate(9600)
        self.assertEqual(self.connection.baudRate, 9600)
    
    def test_setBaudRate_115200(self):
        """Test setBaudRate with 115200"""
        self.connection.setBaudRate(115200)
        self.assertEqual(self.connection.baudRate, 115200)
    
    # ==================== is_connected() Tests ====================
    def test_is_connected_initially_false(self):
        """Test is_connected returns False when not connected"""
        self.assertFalse(self.connection.is_connected())
    
    # ==================== open() Tests ====================
    def test_open_without_port_returns_false(self):
        """Test open returns False when no port is set"""
        result = self.connection.open()
        self.assertFalse(result)
    
    @patch('serial.Serial')
    def test_open_with_valid_port(self, mock_serial):
        """Test open returns True with valid port"""
        mock_serial.return_value.is_open = True
        self.connection.setComPort("COM3")
        result = self.connection.open()
        self.assertTrue(result)
    
    @patch('serial.Serial')
    def test_open_sets_is_running(self, mock_serial):
        """Test open sets _is_running to True"""
        mock_serial.return_value.is_open = True
        self.connection.setComPort("COM3")
        self.connection.open()
        self.assertTrue(self.connection._is_running)
    
    # ==================== close() Tests ====================
    def test_close_returns_true(self):
        """Test close returns True"""
        result = self.connection.close()
        self.assertTrue(result)
    
    def test_close_sets_is_running_false(self):
        """Test close sets _is_running to False"""
        self.connection._is_running = True
        self.connection.close()
        self.assertFalse(self.connection._is_running)
    
    # ==================== getAmbientTemp() Tests ====================
    def test_getAmbientTemp_initial_value(self):
        """Test getAmbientTemp returns initial value"""
        result = self.connection.getAmbientTemp()
        self.assertEqual(result, 0.0)
    
    def test_getAmbientTemp_after_update(self):
        """Test getAmbientTemp returns updated value"""
        self.connection.ambientTemperature = 25.5
        result = self.connection.getAmbientTemp()
        self.assertEqual(result, 25.5)
    
    # ==================== getDesiredTemp() Tests ====================
    def test_getDesiredTemp_initial_value(self):
        """Test getDesiredTemp returns initial value"""
        result = self.connection.getDesiredTemp()
        self.assertEqual(result, 0.0)
    
    def test_getDesiredTemp_after_update(self):
        """Test getDesiredTemp returns updated value"""
        self.connection.desiredTemperature = 22.0
        result = self.connection.getDesiredTemp()
        self.assertEqual(result, 22.0)
    
    # ==================== getFanSpeed() Tests ====================
    def test_getFanSpeed_initial_value(self):
        """Test getFanSpeed returns initial value"""
        result = self.connection.getFanSpeed()
        self.assertEqual(result, 0)
    
    def test_getFanSpeed_after_update(self):
        """Test getFanSpeed returns updated value"""
        self.connection.fanSpeed = 120
        result = self.connection.getFanSpeed()
        self.assertEqual(result, 120)
    
    # ==================== setDesiredTemp() Tests ====================
    def test_setDesiredTemp_not_connected_returns_false(self):
        """Test setDesiredTemp returns False when not connected"""
        result = self.connection.setDesiredTemp(25.0)
        self.assertFalse(result)
    
    @patch('serial.Serial')
    def test_setDesiredTemp_valid_temp(self, mock_serial):
        """Test setDesiredTemp with valid temperature"""
        mock_serial_instance = MagicMock()
        mock_serial.return_value = mock_serial_instance
        mock_serial_instance.is_open = True
        
        self.connection.setComPort("COM3")
        self.connection.open()
        result = self.connection.setDesiredTemp(25.0)
        self.assertTrue(result)
    
    # ==================== update() Tests ====================
    def test_update_not_connected(self):
        """Test update does nothing when not connected"""
        # Should not raise exception
        self.connection.update()
        self.assertEqual(self.connection.ambientTemperature, 0.0)


class TestCurtainControlSystemConnection(unittest.TestCase):
    """Test cases for CurtainControlSystemConnection class"""
    
    def setUp(self):
        """Set up test fixtures"""
        self.connection = CurtainControlSystemConnection()
    
    def tearDown(self):
        """Clean up after tests"""
        if self.connection.is_connected():
            self.connection.close()
    
    # ==================== setComPort() Tests ====================
    def test_setComPort_with_integer(self):
        """Test setComPort with integer port number"""
        self.connection.setComPort(8)
        self.assertEqual(self.connection.comPort, "COM8")
    
    def test_setComPort_with_string(self):
        """Test setComPort with string port name"""
        self.connection.setComPort("CNCB0")
        self.assertEqual(self.connection.comPort, "CNCB0")
    
    # ==================== setBaudRate() Tests ====================
    def test_setBaudRate(self):
        """Test setBaudRate"""
        self.connection.setBaudRate(9600)
        self.assertEqual(self.connection.baudRate, 9600)
    
    # ==================== is_connected() Tests ====================
    def test_is_connected_initially_false(self):
        """Test is_connected returns False when not connected"""
        self.assertFalse(self.connection.is_connected())
    
    # ==================== open() Tests ====================
    def test_open_without_port_returns_false(self):
        """Test open returns False when no port is set"""
        result = self.connection.open()
        self.assertFalse(result)
    
    # ==================== close() Tests ====================
    def test_close_returns_true(self):
        """Test close returns True"""
        result = self.connection.close()
        self.assertTrue(result)
    
    # ==================== getOutdoorTemp() Tests ====================
    def test_getOutdoorTemp_initial_value(self):
        """Test getOutdoorTemp returns initial value"""
        result = self.connection.getOutdoorTemp()
        self.assertEqual(result, 0.0)
    
    def test_getOutdoorTemp_after_update(self):
        """Test getOutdoorTemp returns updated value"""
        self.connection.outdoorTemperature = 15.5
        result = self.connection.getOutdoorTemp()
        self.assertEqual(result, 15.5)
    
    # ==================== getOutdoorPress() Tests ====================
    def test_getOutdoorPress_initial_value(self):
        """Test getOutdoorPress returns initial value"""
        result = self.connection.getOutdoorPress()
        self.assertEqual(result, 0.0)
    
    def test_getOutdoorPress_after_update(self):
        """Test getOutdoorPress returns updated value"""
        self.connection.outdoorPressure = 1013.25
        result = self.connection.getOutdoorPress()
        self.assertEqual(result, 1013.25)
    
    # ==================== getCurtainStatus() Tests ====================
    def test_getCurtainStatus_initial_value(self):
        """Test getCurtainStatus returns initial value"""
        result = self.connection.getCurtainStatus()
        self.assertEqual(result, 0.0)
    
    def test_getCurtainStatus_after_update(self):
        """Test getCurtainStatus returns updated value"""
        self.connection.curtainStatus = 75.0
        result = self.connection.getCurtainStatus()
        self.assertEqual(result, 75.0)
    
    # ==================== getLightIntensity() Tests ====================
    def test_getLightIntensity_initial_value(self):
        """Test getLightIntensity returns initial value"""
        result = self.connection.getLightIntensity()
        self.assertEqual(result, 0.0)
    
    def test_getLightIntensity_after_update(self):
        """Test getLightIntensity returns updated value"""
        self.connection.lightIntensity = 500.0
        result = self.connection.getLightIntensity()
        self.assertEqual(result, 500.0)
    
    # ==================== setCurtainStatus() Tests ====================
    def test_setCurtainStatus_not_connected_returns_false(self):
        """Test setCurtainStatus returns False when not connected"""
        result = self.connection.setCurtainStatus(50.0)
        self.assertFalse(result)
    
    @patch('serial.Serial')
    def test_setCurtainStatus_valid_position(self, mock_serial):
        """Test setCurtainStatus with valid position"""
        mock_serial_instance = MagicMock()
        mock_serial.return_value = mock_serial_instance
        mock_serial_instance.is_open = True
        
        self.connection.setComPort("COM8")
        self.connection.open()
        result = self.connection.setCurtainStatus(50.0)
        self.assertTrue(result)
    
    # ==================== update() Tests ====================
    def test_update_not_connected(self):
        """Test update does nothing when not connected"""
        # Should not raise exception
        self.connection.update()
        self.assertEqual(self.connection.curtainStatus, 0.0)


def run_tests():
    """Run all tests and display results"""
    print("=" * 60)
    print("Home Automation System - Connection Class Tests")
    print("[R2.3-2] Testing each member function of classes")
    print("=" * 60)
    
    # Create test suite
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # Add test cases
    suite.addTests(loader.loadTestsFromTestCase(TestAirConditionerSystemConnection))
    suite.addTests(loader.loadTestsFromTestCase(TestCurtainControlSystemConnection))
    
    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # Summary
    print("\n" + "=" * 60)
    print("TEST SUMMARY")
    print("=" * 60)
    print(f"Tests Run: {result.testsRun}")
    print(f"Failures: {len(result.failures)}")
    print(f"Errors: {len(result.errors)}")
    print(f"Success: {result.wasSuccessful()}")
    
    return result.wasSuccessful()


if __name__ == "__main__":
    run_tests()
