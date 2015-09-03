//
//  ViewController.m
//  iOS7_BarcodeScanner
//
//  Created by Jake Widmer on 11/16/13.
//  Copyright (c) 2013 Jake Widmer. All rights reserved.
//


#import "ScannerViewController.h"
#import "SettingsViewController.h"
#import "Barcode.h"

 #include <CommonCrypto/CommonHMAC.h>

@import AVFoundation;   // iOS7 only import style

@interface ScannerViewController ()

@property (strong, nonatomic) NSMutableArray * foundBarcodes;
@property (weak, nonatomic) IBOutlet UIView *previewView;

@property (strong, nonatomic) SettingsViewController * settingsVC;

@end
@implementation ScannerViewController {
    
    
    /* Here’s a quick rundown of the instance variables (via 'iOS 7 By Tutorials'):
     
     1. _captureSession – AVCaptureSession is the core media handling class in AVFoundation. It talks to the hardware to retrieve, process, and output video. A capture session wires together inputs and outputs, and controls the format and resolution of the output frames.
     
     2. _videoDevice – AVCaptureDevice encapsulates the physical camera on a device. Modern iPhones have both front and rear cameras, while other devices may only have a single camera.
     
     3. _videoInput – To add an AVCaptureDevice to a session, wrap it in an AVCaptureDeviceInput. A capture session can have multiple inputs and multiple outputs.
     
     4. _previewLayer – AVCaptureVideoPreviewLayer provides a mechanism for displaying the current frames flowing through a capture session; it allows you to display the camera output in your UI.
     5. _running – This holds the state of the session; either the session is running or it’s not.
     6. _metadataOutput - AVCaptureMetadataOutput provides a callback to the application when metadata is detected in a video frame. AV Foundation supports two types of metadata: machine readable codes and face detection.
     7. _backgroundQueue - Used for showing alert using a separate thread.
     */
    AVCaptureSession *_captureSession;
    AVCaptureDevice *_videoDevice;
    AVCaptureDeviceInput *_videoInput;
    AVCaptureVideoPreviewLayer *_previewLayer;
    BOOL _running;
    AVCaptureMetadataOutput *_metadataOutput;
}
@synthesize message=_message;

-(NSString*)hmacSHA256:(NSString *)key andData: (NSString *)data
{
    const char *cKey  = [key cStringUsingEncoding:NSASCIIStringEncoding];
    const char *cData = [data cStringUsingEncoding:NSASCIIStringEncoding];
    unsigned char cHMAC[CC_SHA512_DIGEST_LENGTH];

    CCHmac(kCCHmacAlgSHA512, cKey, strlen(cKey), cData, strlen(cData), cHMAC);
    
    NSMutableString *result = [NSMutableString string];
    int hasta =sizeof (cHMAC);
    int i=0;
//    NSData *datas = [NSData dataWithBytes:cHMAC length:hasta];
  //  NSString *encoded = [datas base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    for (i = 0; i < hasta; i++)
    {
        [result appendFormat:@"%02hhx", cHMAC[i]];
    }
    //result is hex
    //encoded is base64
    return result;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupCaptureSession];
    _previewLayer.frame = _previewView.bounds;
    [_previewView.layer addSublayer:_previewLayer];
    self.foundBarcodes = [[NSMutableArray alloc] init];
    
    // listen for going into the background and stop the session
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(applicationWillEnterForeground:)
     name:UIApplicationWillEnterForegroundNotification
     object:nil];
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(applicationDidEnterBackground:)
     name:UIApplicationDidEnterBackgroundNotification
     object:nil];
    
    // set default allowed barcode types, remove types via setings menu if you don't want them to be able to be scanned
    self.allowedBarcodeTypes = [NSMutableArray new];
    [self.allowedBarcodeTypes addObject:@"org.iso.QRCode"];
    [self.allowedBarcodeTypes addObject:@"org.iso.PDF417"];
    [self.allowedBarcodeTypes addObject:@"org.gs1.UPC-E"];
    [self.allowedBarcodeTypes addObject:@"org.iso.Aztec"];
    [self.allowedBarcodeTypes addObject:@"org.iso.Code39"];
    [self.allowedBarcodeTypes addObject:@"org.iso.Code39Mod43"];
    [self.allowedBarcodeTypes addObject:@"org.gs1.EAN-13"];
    [self.allowedBarcodeTypes addObject:@"org.gs1.EAN-8"];
    [self.allowedBarcodeTypes addObject:@"com.intermec.Code93"];
    [self.allowedBarcodeTypes addObject:@"org.iso.Code128"];
    
    
  
   
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self startRunning];
}


- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopRunning];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
#pragma mark - AV capture methods

- (void)setupCaptureSession {
    // 1
    if (_captureSession) return;
    // 2
    _videoDevice = [AVCaptureDevice
                    defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (!_videoDevice) {
        NSLog(@"No video camera on this device!");
        return;
    }
    // 3
    _captureSession = [[AVCaptureSession alloc] init];
    // 4
    _videoInput = [[AVCaptureDeviceInput alloc]
                   initWithDevice:_videoDevice error:nil];
    // 5
    if ([_captureSession canAddInput:_videoInput]) {
        [_captureSession addInput:_videoInput];
    }
    // 6
    _previewLayer = [[AVCaptureVideoPreviewLayer alloc]
                     initWithSession:_captureSession];
    _previewLayer.videoGravity =
    AVLayerVideoGravityResizeAspectFill;
    
    
    // capture and process the metadata
    _metadataOutput = [[AVCaptureMetadataOutput alloc] init];
    dispatch_queue_t metadataQueue =
    dispatch_queue_create("com.1337labz.featurebuild.metadata", 0);
    [_metadataOutput setMetadataObjectsDelegate:self
                                          queue:metadataQueue];
    if ([_captureSession canAddOutput:_metadataOutput]) {
        [_captureSession addOutput:_metadataOutput];
    }
}

- (void)startRunning {
    if (_running) return;
    [_captureSession startRunning];
    _metadataOutput.metadataObjectTypes =
    _metadataOutput.availableMetadataObjectTypes;
    _running = YES;
}
- (void)stopRunning {
    if (!_running) return;
    [_captureSession stopRunning];
    _running = NO;
}

//  handle going foreground/background
- (void)applicationWillEnterForeground:(NSNotification*)note {
    [self startRunning];
}
- (void)applicationDidEnterBackground:(NSNotification*)note {
    [self stopRunning];
}

#pragma mark - Button action functions
- (IBAction)settingsButtonPressed:(id)sender {
    [self performSegueWithIdentifier:@"toSettings" sender:self];
}
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"toSettings"]) {
        self.settingsVC = (SettingsViewController *)[self.storyboard instantiateViewControllerWithIdentifier: @"SettingsViewController"];
        self.settingsVC = segue.destinationViewController;
        self.settingsVC.delegate = self;
    }
}


#pragma mark - Delegate functions

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputMetadataObjects:(NSArray *)metadataObjects
       fromConnection:(AVCaptureConnection *)connection
{
    [metadataObjects
     enumerateObjectsUsingBlock:^(AVMetadataObject *obj,
                                  NSUInteger idx,
                                  BOOL *stop)
     {
         if ([obj isKindOfClass:
              [AVMetadataMachineReadableCodeObject class]])
         {
             // 3
             AVMetadataMachineReadableCodeObject *code =
             (AVMetadataMachineReadableCodeObject*)
             [_previewLayer transformedMetadataObjectForMetadataObject:obj];
             // 4
             Barcode * barcode = [Barcode processMetadataObject:code];
             
             for(NSString * str in self.allowedBarcodeTypes){
                 if([barcode.getBarcodeType isEqualToString:str]){
                     [self validBarcodeFound:barcode];
                     return;
                 }
             }
         }
     }];
}

- (void) validBarcodeFound:(Barcode *)barcode{
    [self stopRunning];
    [self.foundBarcodes addObject:barcode];
    [self showBarcodeAlert:barcode];
}

-(NSString *) URLEncodeString:(NSString *) str
{
    
    NSMutableString *tempStr = [NSMutableString stringWithString:str];
    [tempStr replaceOccurrencesOfString:@" " withString:@"+" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [tempStr length])];
    
    
    return [[NSString stringWithFormat:@"%@",tempStr] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}
- (void) showBarcodeAlert:(Barcode *)barcode{
    dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Code to do in background processing
        
        NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration: defaultConfigObject delegate: nil delegateQueue: [NSOperationQueue mainQueue]];
       
        NSDate *hoy = [NSDate date];
        
        
        NSDateComponents *components = [[NSCalendar currentCalendar] components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear fromDate:hoy];
        
        
        int day = (int)[components day];
        int month = (int)[components month];
        int year = (int)[components year];
        NSString *M, *Y,*D;
        if(month<10)
        {
            M=[NSString stringWithFormat:@"0%d",month];
        }
        else
        {
            M=[NSString stringWithFormat:@"%d",month];
        }
        if(day<10)
        {
            D=[NSString stringWithFormat:@"0%d",day];
        }
        else
        {
            D=[NSString stringWithFormat:@"%d",day];
        }
        Y=[NSString stringWithFormat:@"%d",year];
        
        NSString *initSalt = @"%&/mysalt5=";
        NSString *endSalt = @"ThisIsMyEasyToRememberSalt";
        
        NSString *clave = [NSString stringWithFormat:@"%@%@%@%@%@", initSalt,Y,M,D,endSalt];
        NSString *keyword=@"7HolaAmigosComoEstan7";
        
        
     NSString* cypherText =  [self hmacSHA256:keyword andData:clave];
        NSString *urlString =[NSString stringWithFormat:@"http://sunplus.redirectme.net:90/?accion=1&argumento1=%@&ei=%@",[barcode getBarcodeData],cypherText ];
        
        NSURL * url = [NSURL URLWithString:urlString];
        
        NSMutableURLRequest * urlRequest = [NSMutableURLRequest requestWithURL:url];
//        NSString * params =[NSString stringWithFormat:@"accion=1&argumento1=%@", [barcode getBarcodeData]];
        [urlRequest setHTTPMethod:@"POST"];//GET
  //      [urlRequest setHTTPBody:[params dataUsingEncoding:NSUTF8StringEncoding]];
        
        NSURLSessionDataTask * dataTask =[defaultSession dataTaskWithRequest:urlRequest
                                                           completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                               NSLog(@"Responsess:%@ %@\n", response, error);
                                                               if(error == nil)
                                                               {
                                                                   NSString * text = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
                                                                   NSLog(@"Data = %@",text);
                                                                   
                                                                   
                                                                   
                                                                   
                                                                   
                                                                   NSError* error;
                                                                   NSArray* json = [NSJSONSerialization
                                                                                    JSONObjectWithData:data
                                                                                    options:kNilOptions
                                                                                    error:&error];
                                                                   
                                                                   NSDictionary* latest = [json objectAtIndex:0];
                                                                   
                                                                   
                                                                   NSString * alertMessage = @"El Activo Fijo tiene las siguientes propiedades:\n";
                                                                   
                                                                   
                                                                   alertMessage = [alertMessage stringByAppendingString:[NSString stringWithFormat:@"\nID: %@",[latest objectForKey:@"ASSET_CODE"]]
                                                                                   ];
                                                                   
                                                                   alertMessage = [alertMessage stringByAppendingString:[NSString stringWithFormat:@"\nDescripción: %@",[latest objectForKey:@"DESCR"]]
                                                                                   ];
                                                                   alertMessage = [alertMessage stringByAppendingString:[NSString stringWithFormat:@"\nPeriodo Inicio: %@",[latest objectForKey:@"START_PERD"]]];
                                                                   
                                                                   alertMessage = [alertMessage stringByAppendingString:[NSString stringWithFormat:@"\nPeriodo Final: %@",[latest objectForKey:@"LAST_PERD"]]];
                                                                   
                                                                   alertMessage = [alertMessage stringByAppendingString:[NSString stringWithFormat:@"\nBase: $%@",[latest objectForKey:@"BASE_GROSS"]]];
                                                                   
                                                                   alertMessage = [alertMessage stringByAppendingString:[NSString stringWithFormat:@"\nDepreciado: $%@",[latest objectForKey:@"BASE_DEP"]]];
                                                                   
                                                                   alertMessage = [alertMessage stringByAppendingString:[NSString stringWithFormat:@"\nNeto: $%@",[latest objectForKey:@"BASE_NET"]]];
                                                                   
                                                                   alertMessage = [alertMessage stringByAppendingString:[NSString stringWithFormat:@"\nPorcentaje de Dep. :  %@",[latest objectForKey:@"BASE_PCENT"]]];
                                                                   
                                                                   
                                                                   _message = [[UIAlertView alloc] initWithTitle:@"Activo Fijo"
                                                                                                         message:alertMessage
                                                                                                        delegate:self
                                                                                               cancelButtonTitle:@"Ok"
                                                                                               otherButtonTitles:nil];
                                                                   
                                                                   [_message show];
                                                                   
                                                                   [self startRunning];
                                                                   
                                                               }
                                                               
                                                           }];
        
        [dataTask resume];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // Code to update the UI/send notifications based on the results of the background processing
            //            [_message show];
            
            
        });
    });
}
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    if(buttonIndex == 0){
        //Code for Done button
        // TODO: Create a finished view
    }
    if(buttonIndex == 1){
        //Code for Scan more button
        [self startRunning];
    }
}

- (void) settingsChanged:(NSMutableArray *)allowedTypes{
    for(NSObject * obj in allowedTypes){
        NSLog(@"%@",obj);
    }
    if(allowedTypes){
        self.allowedBarcodeTypes = [NSMutableArray arrayWithArray:allowedTypes];
    }
}

@end


