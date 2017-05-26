angular.module('starter.controllers', [])

.controller('AppCtrl', function($rootScope, $scope, $ionicModal, $timeout, IPCService) {
  $rootScope.ipcEnabled = false;
  $rootScope.rfidEnabled = false;
            
  $scope.$on('$stateChangeStart', function(event, toState, toParams, fromState, fromParams){ 
    if($rootScope.ipcEnabled)
    {
      // Reset the callbacks
      IPCService.clearCallbacks();
    }
  });
})

.controller('ScanCtrl', function($scope, $rootScope, IPCService) {

    $scope.actionEvent = "";
    $scope.results = "";

    $scope.autoTimeoutTime = 3400;
    $scope.passThrough = false;
    $scope.deviceCharge = false;

    $scope.onSuccess = function(data){
      $scope.results = "";

      setTimeout(function () {
        $scope.$apply(function () {
          $scope.results = data;
        });
      });
    }

    $scope.onError = function(data){
      $scope.results = "";

      setTimeout(function () {
        $scope.$apply(function () {
          $scope.results = data;
        });
      });
    }

    $scope.barcodeResult = function(barcode, type, typeText) {
      $scope.results = "";

      setTimeout(function () {
        $scope.$apply(function () {
          $scope.results = 'barcode: ' + barcode + ' type: ' + type + ' typeText:' + typeText;
        });
      });
    };

    $scope.$on("$ionicView.enter", function(event, data){
      IPCService.successCallback($scope.onSuccess);
      IPCService.errorCallback($scope.onError);
      IPCService.barcodeCallback($scope.barcodeResult);

      IPCService.init();
    });

    /* Hardware Functions */
    $scope.scanOn = function(){
      if( $rootScope.ipcEnabled)
      {
        IPCService.scanOn();
        $scope.actionEvent = 'Hardware laser activated';
      }
      else{
        $scope.actionEvent = "Hardware not active.";
      }
    };

    $scope.scanOff = function(){
      if( $rootScope.ipcEnabled)
      {
        IPCService.scanOff();
        $scope.actionEvent = 'Hardware laser deactivated';
      }
      else{
        $scope.actionEvent = "Hardware not active.";
      }
    };

    $scope.deviceInfo = function(){
      IPCService.deviceInfo();
      $scope.actionEvent = 'Device Info';
    }

    $scope.setAutoTimeout = function(){
      IPCService.setAutoTimeout($scope.autoTimeoutTime);
      $scope.actionEvent = 'Set AutoTimeout: ' + $scope.autoTimeoutTime;
    }

    $scope.setPassThrough = function(){
      $scope.passThrough = !$scope.passThrough;

      IPCService.setPassThrough($scope.passThrough);
      $scope.actionEvent = 'Set Passthrough: ' + $scope.passThrough;
    }

    $scope.setDeviceCharge = function(){
      $scope.deviceCharge = !$scope.deviceCharge;

      IPCService.setDeviceCharge($scope.deviceCharge);
      $scope.actionEvent = 'Set Device Charge ' + $scope.deviceCharge;
    }
})

.controller('MSRCtrl', function($scope, $rootScope, IPCService) {

    $scope.actionEvent = "";
    $scope.results = "";

    
   $scope.onSuccess = function(data){
      $scope.results = "";
      setTimeout(function () {
        $scope.$apply(function () {
          $scope.results = data;
        });
      });
    }

    $scope.onError = function(data){
      $scope.results = "";
      setTimeout(function () {
        $scope.$apply(function () {
          $scope.results = data;
        });
      });
    }

    $scope.msrResult = function(data) {
      $scope.results = "";
      setTimeout(function () {
        $scope.$apply(function () {
          $scope.results = data;
        });
      });
    };

    $scope.$on("$ionicView.enter", function(event, data){
      IPCService.successCallback($scope.onSuccess);
      IPCService.errorCallback($scope.onError);
      IPCService.msrCallback($scope.msrResult);

      IPCService.init();
    });
})

.controller('RFIDCtrl', function($scope, $rootScope, IPCService) {

    $scope.actionEvent = "";
    $scope.results = "";

    
   $scope.onSuccess = function(data){
      $scope.results = "";
      setTimeout(function () {
        $scope.$apply(function () {
          $scope.results = data;
        });
      });
    }

    $scope.onError = function(data){
      $scope.results = "";
      setTimeout(function () {
        $scope.$apply(function () {
          $scope.results = data;
        });
      });
    }

    $scope.rfidResult = function(data) {
      $scope.results = "";
      setTimeout(function () {
        $scope.$apply(function () {
          $scope.results = data;
        });
      });
    };

    $scope.$on("$ionicView.enter", function(event, data){
      IPCService.successCallback($scope.onSuccess);
      IPCService.errorCallback($scope.onError);
      IPCService.rfidCallback($scope.rfidResult);

      IPCService.init();
    });
})

.service('IPCService', function($q, $rootScope) {

    var vm = this;

    vm.deviceNotConnectedError = "Device not connected";
    
    vm._returnStatus = function(available, rfid){
        // Overwrite
        $rootScope.ipcEnabled = available;    
        $rootScope.rfidEnabled = rfid;
    };

    vm._barcodeCallback = function(barcode, type, typeText){
        // Overwrite
    };

    vm._msrCallback = function(data){
        // Overwrite
    };

    vm._rfidCallback = function(data){
        // Overwrite
    };

    vm._returnButtonPressed = function(buttonIndex, status){
        // Overwrite
    };

    vm._successCallback = function(data){
        // Overwrite
    };

    vm._errorCallback = function(data){
        // Overwrite
    };

    vm.onBarcodeStatus = function (available, rfid) {
        console.log('vm.onBarcodeStatus = barcode status: ' + available + ' rfid support ' + rfid);
        vm._returnStatus(available, rfid);
    };
    
    vm.onBarcodeData = function (barcode, type, typeText) {
      console.log('vm.onBarcodeData = barcode: ' + barcode + ' type: ' + type + ' typeText:' + typeText);
      vm._barcodeCallback(barcode, type, typeText);
    };

    vm.onButtonStatus = function (buttonIndex, status) {
      console.log('vm.onButtonStatus =  buttonIndex: ' + buttonIndex, + ' status: ' + status);
      vm._returnButtonPressed(buttonIndex, status);
    };

    vm.onMSRData = function (data) {
      console.log('vm.onMSRData = data: ' + data);
      vm._msrCallback(data);
    };

    vm.onRFIDData = function (data) {
      console.log('vm.onRFIDData = data: ' + data);
      vm._rfidCallback(data);
    };

    vm.onSuccess = function(data){
      console.log('vm.onSuccess =  '+ data);
      vm._successCallback(data);
    }

    vm.onError = function(data){
      console.log('vm.onError =  '+ data);
      vm._errorCallback(data);
    }

    return {
        init: function(){
            try
            {
              Infinea.barcodeStatusCallback = vm.onBarcodeStatus;
              Infinea.barcodeDataCallback = vm.onBarcodeData;
              Infinea.buttonPressedCallback = vm.onButtonStatus;

              Infinea.msrDataCallback = vm.onMSRData;
              Infinea.rfidDataCallback = vm.onRFIDData;

              Infinea.init(vm.onSuccess, vm.onError); 
            }
            catch(err)
            {
              console.log(err);
            }
        },

        clearCallbacks: function(){
            try
            {
              var clearFunction = function(){};
              vm._barcodeCallback = clearFunction;
              vm._onMSRData = clearFunction;
              vm._successCallback = clearFunction;
              vm._errorCallback = clearFunction;
            }
            catch(err)
            {
              console.log(err);
            }
        },

        barcodeCallback: function(userControlFunction){
            vm._barcodeCallback = userControlFunction;
        },

        msrCallback: function(userControlFunction){
            vm._msrCallback = userControlFunction;
        },

        rfidCallback: function(userControlFunction){
            vm._rfidCallback = userControlFunction;
        },

        successCallback:function(userControlFunction){
            vm._successCallback = userControlFunction;
        },

        errorCallback:function(userControlFunction){
            vm._errorCallback = userControlFunction;
        },

        deviceInfo: function(){
            return Infinea.deviceInfo(vm.onSuccess, vm.onError);
        },

        setAutoTimeout: function(timeout){
            if($rootScope.ipcEnabled){
              return Infinea.setAutoTimeout(vm.onSuccess, vm.onError, timeout);
            }
            else{
              return vm.deviceNotConnectedError;
            }
        },

        setPassThrough: function(on){
            if($rootScope.ipcEnabled){
              return Infinea.setPassThrough(vm.onSuccess, vm.onError, on);
            }
            else{
              return vm.deviceNotConnectedError;
            }
        },

        setDeviceCharge: function(on){
            if($rootScope.ipcEnabled){
              return Infinea.setDeviceCharge(vm.onSuccess, vm.onError, on);
            }
            else{
              return vm.deviceNotConnectedError;
            }
        },

        scanOn: function(){
            if($rootScope.ipcEnabled){
              return Infinea.barcodeScan(vm.onSuccess, vm.onError, 'on');
            }
            else{
              return vm.deviceNotConnectedError;
            }
        },

        scanOff: function(){
            if($rootScope.ipcEnabled){
              return Infinea.barcodeScan(vm.onSuccess, vm.onError, 'off');
            }
            else{
              return vm.deviceNotConnectedError;
            }
        },
        scanStatus: function(){
            var scantype = "camera";
            if($rootScope.ipcEnabled){
                scantype = "hardware";
            }
            return scantype;
        }   
    }  
});
