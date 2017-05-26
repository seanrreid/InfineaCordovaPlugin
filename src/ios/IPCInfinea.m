#import "IPCInfinea.h" 

#define TYPE_INTEGER 0x02
#define TYPE_BIT_STRING 0x03
#define TYPE_OCTET_STRING 0x04
#define TYPE_NULL 0x05
#define TYPE_OBJECT_IDENTIFIER 0x06
#define TYPE_SEQUENCE 0x10
#define TYPE_SET 0x11
#define TYPE_PrintableString 0x13
#define TYPE_T61String 0x14
#define TYPE_IA5String 0x16
#define TYPE_UTCTime 0x17

#include "stdio.h"

typedef struct tlv_t
{
	unsigned long tag;
	int tagClass;
	bool constructed;
	int length;
	const unsigned char *data;
}tlv_t;

int tlvMakeTag(unsigned long tag, const unsigned char *inData, int inLength, unsigned char *outData);
tlv_t *tlvFindArray(const unsigned char *data, size_t length, const unsigned long tags[]);
tlv_t *tlvFind(const unsigned char *data, size_t length, const char *tags);
tlv_t *tlvFind1(const unsigned char *data, size_t length, unsigned long tag);

#define CLASS_UNIVERSAL 0x00
#define CLASS_APPLICATION 0x01
#define CLASS_CONTEXT_SPECIFIC 0x02
#define CLASS_PRIVATE 0x03

#define TYPE_PRIMITIVE 0x00
#define TYPE_CONSTRUCTED (1<<5)

static tlv_t tlv;

int tlvMakeTag(unsigned long tag, const unsigned char *inData, int inLength, unsigned char *outData)
{
	int outLen=0;
	if(tag&0xff00)
		outData[outLen++]=(tag>>8);
	outData[outLen++]=tag;
	if(inLength>127)
	{//long form
		outData[outLen++]=0x80|(inLength>>8);
	}
	outData[outLen++]=inLength;
	if(inData && inLength)
		memcpy(&outData[outLen],inData,inLength);
	outLen+=inLength;
	return outLen;
}

tlv_t *tlvFindArray(const unsigned char *data, size_t length, const unsigned long tags[])
{
	tlv_t *found=0;
	for(int i=0;tags[i];i++)
	{
		found=tlvFind1(data,length,tags[i]);
		if(!found)
			return 0;
		data=found->data;
		length=found->length;
	}
	return found;
}

static const char *_parseTag(const char *data, unsigned long *tag)
{
	*tag=0;
	while(1)
	{
		*tag<<=4;
		
		char c=*data;
		if(c>='0' && c<='9')
		{
			*tag|=c-'0';
		}else
		{
			if(c>='a' && c<='f')
				c&=(~0x20);
			if(c>='A' && c<='F')
				*tag|=(c-'A'+10);
			else
			{
				*tag>>=4;
				if(c)
					data++;
				break;
			}
		}
		
		data++;
	}
	return data;
}

tlv_t *tlvFind(const unsigned char *data, size_t length, const char *tags)
{
	tlv_t *found=0;
	while(1)
	{
		unsigned long tag;
		tags=_parseTag(tags,&tag);
		if(!tag)
			break;
		found=tlvFind1(data,length,tag);
		if(!found)
			return 0;
		data=found->data;
		length=found->length;
	}
	return found;
}

tlv_t *tlvFind1(const unsigned char *data, size_t length, unsigned long tag)
{
	for(int i=0;i<length;)
	{
		unsigned char t=data[i++];
		if(i>=length)return NULL;
		
		tlv.tag=t;
		tlv.tagClass=t>>6;
		tlv.constructed=(t&TYPE_CONSTRUCTED)!=0;
		
		if((tlv.tag&0x1F)==0x1F)
		{//2byte tag
			tlv.tag<<=8;
			tlv.tag|=data[i++];
		}
		if(i>=length)return NULL;
		
		tlv.length=0;
		
		if(data[i]&0x80)
		{//long form
			int nBytes=data[i++]&0x7f;
			if(nBytes>2)return NULL;
			for(int j=0;j<nBytes;i++,j++)
			{
				if(i>=length)return NULL;
				tlv.length<<=8;
				tlv.length|=data[i];
			}
		}else
		{//short form
			tlv.length=data[i++]&0x7f;
		}
		if(tlv.length>4096 || i+tlv.length>length)
			return 0;
		
		tlv.data=&data[i];
		
		if(tag==tlv.tag)
			return &tlv;
		
		if(!tlv.constructed)
			i+=tlv.length;
	}
	
	return 0;
}



@implementation Infinea

- (void)pluginInitialize
{
	
}

/* Start - Delegates */

-(void)connectionState:(int)state
{
    NSString *rfidSupport = @"false";
	
    if(state==CONN_CONNECTED)
    {
        NSError *error;
        [sdk barcodeSetTypeMode:BARCODE_TYPE_EXTENDED error:nil];
		
        if([sdk rfInit:CARD_SUPPORT_PICOPASS_ISO15|CARD_SUPPORT_TYPE_A|CARD_SUPPORT_TYPE_B|CARD_SUPPORT_ISO15|CARD_SUPPORT_FELICA error:&error])
        {
            rfidSupport = @"true";
        }
    }
	
    NSString *func=[NSString stringWithFormat:@"%@(%@,%@);",[cb valueForKey:@"barcodeStatusCallback"],state==CONN_CONNECTED?@"true":@"false",rfidSupport];
	
    [(UIWebView*)super.webView stringByEvaluatingJavaScriptFromString:func];
}

-(void)barcodeData:(NSString *)barcode type:(int)type
{
    NSString *func=[NSString stringWithFormat:@"%@(\"%@\",%d,\"%@\");",[cb valueForKey:@"barcodeDataCallback"],barcode,type,[sdk barcodeType2Text:type]];
    [(UIWebView*)super.webView stringByEvaluatingJavaScriptFromString:func];
}

- (void)deviceButtonPressed: (int)which
{
    NSString *func=[NSString stringWithFormat:@"%@(%d,%@);",[cb valueForKey:@"buttonPressedCallback"],which, @"true"];
    NSLog(@"%@",func);
    [(UIWebView*)super.webView stringByEvaluatingJavaScriptFromString:func];
}

- (void)deviceButtonReleased: (int)which
{
    NSString *func=[NSString stringWithFormat:@"%@(%d,%@);",[cb valueForKey:@"buttonPressedCallback"],which, @"false"];
    
    [(UIWebView*)super.webView stringByEvaluatingJavaScriptFromString:func];
}

-(NSString *)JSONEscapedString:(NSString *)aString
{
    NSMutableString *s = [NSMutableString stringWithString:aString];
    [s replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"/" withString:@"\\/" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"\n" withString:@"\\n" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"\b" withString:@"\\b" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"\f" withString:@"\\f" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"\r" withString:@"\\r" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"\t" withString:@"\\t" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [s length])];
    return [NSString stringWithString:s];
}

-(void)magneticCardData:(NSString *)track1 track2:(NSString *)track2 track3:(NSString *)track3 source:(int)source
{
    NSMutableDictionary *dictCardData = [[NSMutableDictionary alloc] init];
    NSDictionary *cardDetails=[sdk msProcessFinancialCard:track1 track2:track2];
    if(cardDetails)
    {
        [dictCardData setObject:cardDetails forKey:@"cardDetails"];
    }
    
    if((track1!=NULL) || (track2!=NULL) || (track3!=NULL))
    {
        NSMutableDictionary *dictTrackData = [[NSMutableDictionary alloc] init];
    
        if(track1!=NULL)
            [dictTrackData setObject:track1 forKey:@"track1"];
        if(track2!=NULL)
            [dictTrackData setObject:track2 forKey:@"track2"];
        if(track3!=NULL)
            [dictTrackData setObject:track3 forKey:@"track3"];
    
        [dictCardData setObject:dictTrackData forKey:@"cardData"];
    }
    
    NSData *JSONData = [NSJSONSerialization dataWithJSONObject:dictCardData
                                                       options:0
                                                         error:nil];
    
    NSString *JSONString = [[NSString alloc] initWithData:JSONData encoding:NSUTF8StringEncoding];
    JSONString = [self JSONEscapedString: JSONString];
    NSString *func=[NSString stringWithFormat:@"%@(\"%@\");",[cb valueForKey:@"msrDataCallback"],JSONString];
    [(UIWebView*)super.webView stringByEvaluatingJavaScriptFromString:func];
}

/* RFID START */

#define RF_COMMAND(operation,c) {if(!c){[self displayAlert:@"Operating failed!" message:[NSString stringWithFormat:@"%@ failed, error %@, code: %d",operation,error.localizedDescription,(int)error.code]]; return;} }


-(void)rfCardDetected:(int)cardIndex info:(DTRFCardInfo *)info
{
	NSError *error;
	
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
	
	 NSMutableDictionary *dictCardData = [[NSMutableDictionary alloc] init];
	
	NSMutableString *log=[[NSMutableString alloc] init];
	[dictCardData setObject:info.typeStr forKey:@"cardType"];
	[dictCardData setObject:hexToString(nil,info.UID.bytes,info.UID.length) forKey:@"serial"];
	
	NSDate *d=[NSDate date];
	switch (info.type)
	{
		case CARD_MIFARE_DESFIRE:
		{
			[NSThread sleepForTimeInterval:0.3];
			NSData *ats=[sdk iso14GetATS:cardIndex error:&error];

			if(ats)
				[dictCardData setObject:hexToString(nil,ats.bytes,ats.length) forKey:@"atsData"];
			
			break;
		}
			
		case CARD_PICOPASS_15693:
		{
			NSData *r;
			tlv_t *t;
			
			r=[sdk hidGetSerialNumber:&error];
			t=tlvFind1(r.bytes, r.length, 0x8A);
			if(t)
			{
				[dictCardData setObject:hexToString(nil,t->data,t->length) forKey:@"hidSerial"];
			}
			
			r=[sdk hidGetVersionInfo:&error];
			t=tlvFind1(r.bytes, r.length, 0x8A); //SamResponse
			if(t)
			{
				t=tlvFind1(t->data, t->length, 0x80); //version
				if(t)
				{
					[dictCardData setObject:[NSString stringWithFormat:@"%d.%d",t->data[0],t->data[1]] forKey:@"version"];
				}
			}
			
			r=[sdk hidGetContentElement:4 pin:nil rootSoOID:nil error:&error];
			t=tlvFind1(r.bytes, r.length, 0x8A); //SamResponse
			if(t)
			{
				t=tlvFind1(t->data, t->length, 0x03); //BitString
				if(t)
				{
					[dictCardData setObject:hexToString(nil,t->data,t->length) forKey:@"contentElement"];
				}
			}
			break;
		}
		case CARD_PAYMENT:
			//[self payCardDemo:cardIndex log:log];
			break;
		case CARD_MIFARE_MINI:
		case CARD_MIFARE_CLASSIC_1K:
		case CARD_MIFARE_CLASSIC_4K:
		case CARD_MIFARE_PLUS:
		{
			NSData *block=[self mifareSafeRead:cardIndex address:8 length:4*16 key:nil error:&error];
			if(block)
				[dictCardData setObject:hexToString(nil,(uint8_t *)block.bytes,block.length) forKey:@"data"];			break;
		}
		case CARD_MIFARE_ULTRALIGHT:
		case CARD_MIFARE_ULTRALIGHT_C:
		{//16 bytes reading, 4 bytes writing
			[NSThread sleepForTimeInterval:0.5];
			//try reading a block
			NSData *block=[sdk mfRead:cardIndex address:8 length:16 error:&error];
			if(block)
				[dictCardData setObject:hexToString(nil,(uint8_t *)block.bytes,block.length) forKey:@"data"];
			
			block=[sdk mfRead:cardIndex address:8 length:16 error:&error];
			if(block)
				[dictCardData setObject:hexToString(nil,(uint8_t *)block.bytes,block.length) forKey:@"data"];
			
			break;
		}
			
		case CARD_ISO15693:
		{
			[dictCardData setObject:[NSString stringWithFormat:@"%d",info.blockSize] forKey:@"blockSize"];
			[dictCardData setObject:[NSString stringWithFormat:@"%d",info.nBlocks] forKey:@"numberOfBlocks"];
			
			NSData *security=[sdk iso15693GetBlocksSecurityStatus:cardIndex startBlock:0 nBlocks:16 error:&error];
			if(security)
				[dictCardData setObject:hexToString(nil,(uint8_t *)security.bytes,security.length) forKey:@"securityStatus"];
			
			//write something to the card
			uint8_t dataToWrite[8];
			for(int i=0;i<sizeof(dataToWrite);i++)
				dataToWrite[i]=(uint8_t)i;
			int r=[sdk iso15693Write:cardIndex startBlock:0 data:[NSData dataWithBytes:dataToWrite length:sizeof(dataToWrite)] error:&error];
			
			//try reading 2 blocks
			NSData *block=[sdk iso15693Read:cardIndex startBlock:0 length:sizeof(dataToWrite) error:&error];
			if(block)
				[dictCardData setObject:hexToString(nil,(uint8_t *)block.bytes,block.length) forKey:@"data"];
			
			break;
		}
		case CARD_FELICA:
		{
			[dictCardData setObject:hexToString(nil,info.felicaPMm.bytes,info.felicaPMm.length) forKey:@"pmm"];
			
			if(info.felicaRequestData)
				[dictCardData setObject:hexToString(nil,info.felicaRequestData.bytes,info.felicaRequestData.length) forKey:@"rqData"];
			
			//write something to the card
			int r;
			
			//custom command
			uint8_t readCmd[]={0x01,0x09,0x00,0x01,0x80,0x00};
			NSData *cmdResponse=[sdk felicaSendCommand:cardIndex command:0x06 data:[NSData dataWithBytes:readCmd length:sizeof(readCmd)] error:&error];
			if(cmdResponse)
				[dictCardData setObject:hexToString(nil,(uint8_t *)cmdResponse.bytes,cmdResponse.length) forKey:@"data"];
			
			//check if the card is FeliCa SmartTag or normal felica
			uint8_t *uid=(uint8_t *)info.UID.bytes;
			if(uid[0]==0x03 && uid[1]==0xFE && uid[2]==0x00 && uid[3]==0x1D)
			{//SmartTag
				//read battery, call this command ALWAYS before communicating with the card
				int battery;
				r=[sdk felicaSmartTagGetBatteryStatus:cardIndex status:&battery error:&error];
				
				NSString *batteryString=@"Unknown";
				
				switch (battery)
				{
					case FELICA_SMARTTAG_BATTERY_NORMAL1:
					case FELICA_SMARTTAG_BATTERY_NORMAL2:
						batteryString=@"Normal";
						break;
					case FELICA_SMARTTAG_BATTERY_LOW1:
						batteryString=@"Low";
						break;
					case FELICA_SMARTTAG_BATTERY_LOW2:
						batteryString=@"Very low";
						break;
				}
				
				[dictCardData setObject:[NSString stringWithFormat:@"%d",battery] forKey:@"battery"];
				[dictCardData setObject:batteryString forKey:@"batteryLevel"];
				
				//perform read/write operations before screen access
				uint8_t dataToWrite[32];
				static uint8_t val=0;
				memset(dataToWrite,val,sizeof(dataToWrite));
				val++;
				r=[sdk felicaSmartTagWrite:cardIndex address:0x0000 data:[NSData dataWithBytes:dataToWrite length:sizeof(dataToWrite)-5] error:&error];
				
				NSData *block=[sdk felicaSmartTagRead:cardIndex address:0x0000 length:sizeof(dataToWrite) error:&error];
				if(block)
					[dictCardData setObject:hexToString(nil,(uint8_t *)block.bytes,block.length) forKey:@"data"];
			}else
			{//Normal
				uint8_t dataToWrite[16]={0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0A,0x0B,0x0C,0x0D,0x0E,0x0F};
				
				//write 1 block
				r=[sdk felicaWrite:cardIndex serviceCode:0x0900 startBlock:0 data:[NSData dataWithBytes:dataToWrite length:sizeof(dataToWrite)] error:&error];
				
				NSData *block=[sdk felicaRead:cardIndex serviceCode:0x0900 startBlock:0 length:sizeof(dataToWrite) error:&error];
				
				if(block)
					[dictCardData setObject:hexToString(nil,(uint8_t *)block.bytes,block.length) forKey:@"data"];
			}
			break;
		}
		case CARD_ST_SRI:
		{
			[dictCardData setObject:[NSString stringWithFormat:@"%d",info.blockSize] forKey:@"blockSize"];
			[dictCardData setObject:[NSString stringWithFormat:@"%d",info.nBlocks] forKey:@"numberOfBlocks"];
			
			const uint8_t dataToWrite[4]={0x00,0x01,0x02,0x03};
			int r=[sdk stSRIWrite:cardIndex address:8 data:[NSData dataWithBytes:dataToWrite length:sizeof(dataToWrite)] error:&error];
			NSData *block=[sdk stSRIRead:cardIndex address:8 length:2*info.blockSize error:&error];
			if(block)
				[dictCardData setObject:hexToString(nil,(uint8_t *)block.bytes,block.length) forKey:@"data"];
		}
		case CARD_EPASSPORT:
		{
			uint16_t apduResult;
			//select lds
			[sdk iso14APDU:cardIndex cla:0x00 ins:0xA4 p1:0x02 p2:0x0C data:stringToData(@"A0 00 00 02 47 10 01")apduResult:&apduResult error:&error];
			
			[sdk iso14APDU:cardIndex cla:0x00 ins:0xA4 p1:0x02 p2:0x0C data:stringToData(@"01 1E") apduResult:&apduResult error:&error];
			
			if(apduResult==0x6982)
			{
				[dictCardData setObject:@true forKey:@"bacRequired"];
			}else
			{
				[dictCardData setObject:@false forKey:@"bacRequired"];
			}
		}
	}

	
	[sdk rfRemoveCard:cardIndex error:nil];
	
	NSData *JSONData = [NSJSONSerialization dataWithJSONObject:dictCardData
													   options:0
														 error:nil];
	
	NSString *JSONString = [[NSString alloc] initWithData:JSONData encoding:NSUTF8StringEncoding];
	JSONString = [self JSONEscapedString: JSONString];
	NSString *func=[NSString stringWithFormat:@"%@(\"%@\");",[cb valueForKey:@"rfidDataCallback"],JSONString];
	[(UIWebView*)super.webView stringByEvaluatingJavaScriptFromString:func];
}


NSData *stringToData(NSString *text)
{
	NSMutableData *d=[NSMutableData data];
	text=[text lowercaseString];
	int count=0;
	uint8_t b=0;
	for(int i=0;i<text.length;i++)
	{
		b<<=4;
		char c=[text characterAtIndex:i];
		if(c<'0' || (c>'9' && c<'a') || c>'f')
		{
			b=0;
			count=0;
			continue;
		}
		if(c>='0' && c<='9')
			b|=c-'0';
		else
			b|=c-'a'+10;
		count++;
		if(count==2)
		{
			[d appendBytes:&b length:1];
			b=0;
			count=0;
		}
	}
	return d;
}

static NSString *dataToString(NSString * label, NSData *data)
{
	return hexToString(label, data.bytes, data.length);
}

static NSString *hexToString(NSString * label, const void *data, size_t length)
{
	const char HEX[]="0123456789ABCDEF";
	char s[20000];
	for(int i=0;i<length;i++)
	{
		s[i*3]=HEX[((uint8_t *)data)[i]>>4];
		s[i*3+1]=HEX[((uint8_t *)data)[i]&0x0f];
		s[i*3+2]=' ';
	}
	s[length*3]=0;
	
	if(label)
		return [NSString stringWithFormat:@"%@(%d): %s",label,(int)length,s];
	else
		return [NSString stringWithCString:s encoding:NSASCIIStringEncoding];
	
}

-(NSData *)mifareSafeRead:(int)cardIndex address:(int)address length:(int)length key:(NSData *)key error:(NSError **)error
{
	if(![self mifareAuthenticate:cardIndex address:address key:key error:error])
		return nil;
	
	NSMutableData *data=[NSMutableData data];
	
	int read=0;
	while (read<length)
	{
		if((address%4)==3)
		{
			address++;
			if(![self mifareAuthenticate:cardIndex address:address key:key error:error])
				return nil;
		}
		
		NSData *block=[sdk mfRead:cardIndex address:address length:16 error:error];
		if(!block)
			return nil;
		[data appendData:block];
		read+=16;
		address++;
	}
	return data;
}


-(bool)mifareAuthenticate:(int)cardIndex address:(int)address key:(NSData *)key error:(NSError **)error
{
	if(key==nil)
	{
		//use the default key
		const uint8_t keyBytes[]={0xFF,0xFF,0xFF,0xFF,0xFF,0xFF};
		key=[NSData dataWithBytes:keyBytes length:sizeof(keyBytes)];
	}
	
#ifdef MIARE_USE_STORED_KEY
	if(![scanDevice mfStoreKeyIndex:0 type:'A' key:key error:error])
		return false;
	if(![scanDevice mfAuthByStoredKey:cardIndex type:'A' address:address keyIndex:0 error:error])
		return false;
#else
	if(![sdk mfAuthByKey:cardIndex type:'A' address:address key:key error:error])
		return false;
#endif
	
	return true;
}


-(bool)mifareSafeWrite:(int)cardIndex address:(int)address data:(NSData *)data key:(NSData *)key error:(NSError **)error
{
	if(address<4) //don't touch the first sector
		return false;
	
	if(![self mifareAuthenticate:cardIndex address:address key:key error:error])
		return nil;
	
	int r;
	int written=0;
	while (written<data.length)
	{
		uint8_t block[16]={0};
		[data getBytes:block range:NSMakeRange(written, MIN(16, data.length-written))];
		
		if((address%4)==3)
		{
			address++;
			if(![self mifareAuthenticate:cardIndex address:address key:key error:error])
				return nil;
		}
		r=[sdk mfWrite:cardIndex address:address data:[NSData dataWithBytes:block length:sizeof(block)] error:error];
		if(!r)
			return false;
		written+=sizeof(block);
		address++;
	}
	return true;
}


#define CHECK_RESULT(description,result) if(result){[log appendFormat:@"%@: SUCCESS\n",description]; NSLog(@"%@: SUCCESS",description);} else {[log appendFormat:@"%@: FAILED (%@)\n",description,error.localizedDescription]; NSLog(@"%@: FAILED (%@)\n",description,error.localizedDescription); }

#define DF_CMD(command,description) r=[dtdev iso14Transceive:info.cardIndex data:[NSData dataWithBytes:command length:sizeof(command)] status:&cardStatus error:&error]; \
if(r) [log appendFormat:@"%@ succeed with status: %@ response: %@\n",description,dfStatus2String(cardStatus),r]; else [log appendFormat:@"%@ failed with error: %@\n",description,error.localizedDescription];

/* RFID END */


/* End - Delegates */

-(void)initWithCallbacks:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;

    @try {
        sdk=[DTDevices sharedDevice];
        sdk.delegate=self;
        [sdk connect];
        [sdk setAutoOffWhenIdle:36000 whenDisconnected:36000 error:nil];
		
        cb= [[command.arguments objectAtIndex:0] copy];
		
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } @catch (id exception) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:exception];
    }
	
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void)deviceInfo:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
	
    @try {
        NSDictionary *deviceDetails = [[NSDictionary alloc] init];
        deviceDetails = [self getDeviceDetails];
		
        NSData *JSONData = [NSJSONSerialization dataWithJSONObject:deviceDetails
                                                           options:0
                                                             error:nil];
		
        NSString *JSONString = [[NSString alloc] initWithData:JSONData encoding:NSUTF8StringEncoding];
		
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:JSONString];
		
		
    } @catch (id exception) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:exception];
    }
	
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (NSDictionary *)getDeviceDetails
{
    NSMutableDictionary *dictDTDevice = [[NSMutableDictionary alloc] init];
    sdk=[DTDevices sharedDevice];
    sdk.delegate=self;
    [sdk connect];

    NSString *hardwareSDK = @"";
    NSString *hardwareSerialNumber = @"";
    NSString *hardwareName = @"";
    NSString *hardwareModel = @"";
    NSString *hardwareRevision = @"";
    NSString *hardwareBattery = @"";
    NSString *hardwareVoltage = @"";
    NSString *hardwareFirmware = @"";
    NSString *hardwareKioskMode = @"";
    NSString *hardwarePassThruSync = @"";
    NSString *hardwareBackupCharge = @"";
    NSString *error = @"";
	
    if (sdk.connstate == CONN_CONNECTED) {
        hardwareSDK = [NSString stringWithFormat:@"%d.%d", sdk.sdkVersion/100, sdk.sdkVersion%100];
        hardwareSerialNumber = sdk.serialNumber;
        hardwareName = sdk.deviceName;
        hardwareModel = sdk.deviceModel;
        hardwareFirmware = sdk.firmwareRevision;
        hardwareRevision = sdk.hardwareRevision;
		
        BOOL isKioskMode = NO;
        [sdk getKioskMode:&isKioskMode error:nil];
        hardwareKioskMode = (isKioskMode ? @"True" : @"False");
		
        // Battery
        DTBatteryInfo *batteryInfo = [sdk getBatteryInfo:nil];
        if (batteryInfo) {
            hardwareBattery = [NSString stringWithFormat:@"%i", batteryInfo.capacity];
            hardwareVoltage = [NSString stringWithFormat:@"%0.2f", batteryInfo.voltage];
        }
        
        // Pass thru sync
        BOOL passThruSync = NO;
        [sdk getPassThroughSync:&passThruSync error:nil];
        hardwarePassThruSync = passThruSync ? @"True" : @"False";

        
        // Backup charge
        BOOL isCharging = NO;
        [sdk getCharging:&isCharging error:nil];
        hardwareBackupCharge = isCharging ? @"True" : @"False";
    }
    else{
        error = @"Device not connected";
    }
    
    // set object
    [dictDTDevice setObject:hardwareFirmware forKey:@"firmware"];
    [dictDTDevice setObject:hardwareModel forKey:@"model"];
    [dictDTDevice setObject:hardwareName forKey:@"hardwareName"];
    [dictDTDevice setObject:hardwareSDK forKey:@"sdkVersion"];
    [dictDTDevice setObject:hardwareSerialNumber forKey:@"serial"];
    [dictDTDevice setObject:hardwareBattery forKey:@"batteryLevel"];
    [dictDTDevice setObject:hardwarePassThruSync forKey:@"passThruSync"];
    [dictDTDevice setObject:hardwareBackupCharge forKey:@"backupCharge"];
    [dictDTDevice setObject:error forKey:@"error"];
    
    return dictDTDevice;
}

-(void)setAutoTimeout:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSError *error;
    
    @try {
        bool success=false;
        int timeOff = [[command.arguments objectAtIndex:0] intValue];
        
        success = [sdk setAutoOffWhenIdle:timeOff whenDisconnected:30 error:&error];
        if (success) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        }
        else
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
        }
    } @catch (id exception) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:exception];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void)setPassThrough:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSError *error;
    
    @try {
        bool success = false;
        bool mode = [[command.arguments objectAtIndex:0] boolValue];
       
        success = [sdk setPassThroughSync:mode error:&error];
        if (success) {
            
            if(!mode){
                success = [sdk setUSBChargeCurrent:1000 error:&error];
                
                if (success) {
                    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                }
                else{
                     pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
                }
            }
            else{
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
            }
        }
        else
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
        }
    } @catch (id exception) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:exception];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void)setDeviceCharge:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSError *error;
    
    @try {
        bool success=false;
        bool mode = [[command.arguments objectAtIndex:0] boolValue];
        
        success = [sdk setCharging:mode error:&error];
        if (success) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        }
        else
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
        }
    } @catch (id exception) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:exception];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void)setDeviceSound:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult* pluginResult = nil;
    NSError *error;
    
    @try {
        bool success=false;
        
        bool scanBeep = [[command.arguments objectAtIndex:0] boolValue];
        int volume = 10;
        int beepData[]={2000,400,5000,400};
        int length = 4;
        
        success = [sdk barcodeSetScanBeep:scanBeep volume:volume beepData:beepData length:length error:&error];
        
        if (success) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        }
        else
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
        }
    } @catch (id exception) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:exception];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void)barScan:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSError *error;
    
    @try {
        NSString* myarg = [[command.arguments objectAtIndex:0] lowercaseString];
        bool success=false;
        
        if([myarg isEqualToString:@"on"] || [myarg isEqualToString:@"yes"] || [myarg isEqualToString:@"true"] || [myarg isEqualToString:@"1"])
            success=[sdk barcodeStartScan:&error];
        else
            success=[sdk barcodeStopScan:&error];
        
        if (success) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        }
        else
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
        }
    } @catch (id exception) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:exception];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void)barSetScanMode:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSError *error;
    
    @try {
        bool success=false;
        
        success=[sdk barcodeSetScanMode:[[command.arguments objectAtIndex:0] intValue] error:&error];

        if (success) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        }
        else
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
        }
    } @catch (id exception) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:exception];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void)barOpticonSetCustomConfig:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSError *error;
    
    @try {
        bool success=false;
        
        success=[sdk barcodeOpticonSetInitString:[command.arguments objectAtIndex:0] error:&error];
        
        if (success) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        }
        else
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
        }
    } @catch (id exception) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:exception];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void)barIntermecSetCustomConfig:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSError *error;
    
    @try {
        bool success=false;
        NSArray *data=[command.arguments objectAtIndex:0];
        uint8_t buf[data.count];
        for(int i=0;i<data.count;i++)
            buf[i]=(uint8_t)[[data objectAtIndex:i] intValue];
        
        success=[sdk barcodeIntermecSetInitData:[NSData dataWithBytes:buf length:sizeof(buf)] error:&error];
        
        if (success) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        }
        else
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
        }
    } @catch (id exception) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:exception];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void)barCodeSetParams:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSError *error;
    
    @try {
        bool success=false;
        NSArray *data=[command.arguments objectAtIndex:0];
        
        for(int i=0;i<data.count;i+=2)
        {
            success=[sdk barcodeCodeSetParam:[[data objectAtIndex:i] intValue] value:[[data objectAtIndex:i+1] intValue] error:&error];
            if(!success)
                break;
        }
        
        
        if (success) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        }
        else
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
        }
    } @catch (id exception) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:exception];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

@end
