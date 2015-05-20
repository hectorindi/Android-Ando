/*
* Copyright (c) 2011 Solid Thinking Interactive All rights reserved.
* Redistribution and use in source and binary forms, with or without modification are not permitted
* Contact Solid Thinking Interactive for more information on licensing 
* http://www.solid-thinking.com
* http://www.fmsguru.com
*
************* 
THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESSED OR IMPLIED WARRANTIES, 
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND 
FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL SOLID THINKING
INTERACTIVE OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, 
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH 
DAMAGE.
*************
* 
* Basic Private Chat version 4.3 for Wowza
* 10/2011
* Solid Thinking Interactive
* FMSGuru.com
* 
*/

package com.encast{
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	
	public class NetConnectionClient extends EventDispatcher{
		
		public static const ON_METADATA:String = "onMetaData";		
		
		private var _privateRoomName:String;
		
		public function NetConnectionClient(target:IEventDispatcher=null){
			super(target);
		}
		
		public function confirmConnection():String{
			return "confirmed";
		}
		
		public function onDataasdEvent(data:String):void
		{
			var tempObj:Object = new Object();
			tempObj.user = data;
			//dispatchEvent(new WowzaCustomEvent(NetConnectionClient.ON_METADATA, true, false, tempObj));
		}
		
		public function close():void
		{
			trace("Close called on client");
		}
		
		public function onMetaData(infoObject:Object):void
		{
			//traceObject(infoObject);
		}
		
		public function traceObject(obj:Object, indent:uint = 0):void
		{
			var indentString:String = "";
			var i:uint;
			var prop:String;
			var val:*;
			for (i = 0; i < indent; i++)
			{
				indentString += "\t";
			}
			for (prop in obj)
			{
				val = obj[prop];
				if (typeof(val) == "object")
				{
					trace(indentString + " "+": [Object]");
					traceObject(val, indent + 1);
				}
				else
				{
					trace(indentString + " " + prop + ": " + val);
				}
			}
		}
		
		public function onDataEvent(infoObject:Object,infoObject2:Object,infoObject3:Object):void
		{
			var key:String;
			var tempObj:Object = new Object();
			tempObj.slide = infoObject3.slide;
			tempObj.step = infoObject3.step;
			dispatchEvent(new WowzaCustomEvent(NetConnectionClient.ON_METADATA, true, false, tempObj));
		}
		
	}
	
}