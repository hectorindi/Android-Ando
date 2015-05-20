package com.AS
{
	import com.encast.ConnectionProperties;
	import com.encast.NetConnectionClient;
	import com.encast.NetConnectionManager;
	import com.encast.WowzaCustomEvent;
	import com.player.CustomPlayerAndroid;
	import com.player.SlideEvent;
	import com.player.SlideQuery;
	import com.player.SlideShow;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Loader;
	import flash.display.MovieClip;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.geom.Matrix;
	import flash.media.Video;
	import flash.net.NetStream;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	
	import spark.components.BorderContainer;
	import spark.components.Group;
	import spark.components.Image;
	import spark.components.Label;
	
	import org.osmf.events.MetadataEvent;
	
	public class Main extends MovieClip
	{
		//private var xml:LoadingXML;
		public var cuePoints_array:Array;
		public var parameters_array:Array;
		private var slideLocationPath:String = "";//http://www.wstream.net/testing/new/slides.swf";
		private var id:int = 0;
		private var StageRef:Group;
		private var frameNum:Number = 0;
		private var Time:Number = 0;
		private var _videoPath:String = "";//"http://www.wstream.net/testing/new/video.flv";
		private var _playlistUrl:String = "";
		private var cue:Object;
		private var parameter:Object;
		private var userArr:Array;
		private var userName:String
		private var StatusTxt:String
		private var NoOfUserCount:Number=0;
		private var watched:Boolean = false;
		private var middle:Boolean = false;
		private var _player:CustomPlayerAndroid;
		private var _slideConta:BorderContainer; 
		private var _playerConta:BorderContainer; 
		private var _inner:Group;
		
		public function get SlideArray():Array
		{
			return _SlideArray;
		}

		public function set SlideArray(value:Array):void
		{
			_SlideArray = value;
		}

		public function get pptName():String
		{
			return _pptName;
		}

		public function set pptName(value:String):void
		{
			_pptName = value;
		}

		private var _callback:Function;
		private var _connectionProps:ConnectionProperties;
		private var _nc:NetConnectionManager;
		private var _ncClient:NetConnectionClient;
		private var _ns:NetStream;
		private var _vid:Video;
		private var slideImage:Image = new Image();
		
		
		private var _isHD:Boolean = false;
		private var _isFullHD:Boolean = false;
		
		
		private var _path:String = "";
		private var _publishPath:String = "";
		private var _time:int = 0;
		
		private var _SlideArray:Array = new Array();
		private var CurrentSlide:int = 1;
		
		private var _debugLab:Label;
		
		private var loader:Loader;
		private var _pptName:String = "";
		private var _slideshow:SlideShow;
		private var _slideQuery:SlideQuery;
		
		private var _live:Boolean = false;
				
		
		public function Main(ref:Group,path:String,callback:Function,player:CustomPlayerAndroid,debugLab:Label,slideshow:SlideShow = null,slideQuery:SlideQuery = null)
		{
			_debugLab = debugLab;
			_player = player;
			_player.addEventListener("SlideChanged",onSlideChanged);
			_callback = callback;
			var pathArray:Array = path.split("&");
			_path = pathArray[0];
			_pptName = pathArray[1];
			_slideshow = slideshow;
			_slideQuery = slideQuery;
			if(_slideshow)
			{
				_slideshow.addEventListener("slideSelected",onSlideSelected);
			}
			
			_playlistUrl = _path+"/playlist.xml";
			
			StageRef = ref;
	
			_inner = ref.getChildByName("inner") as Group;
			_slideConta = _inner.getChildByName("slide") as BorderContainer;
			_slideConta.id
			
			_playerConta = _inner.getChildByName("player") as BorderContainer;		
			_playerConta.invalidateDisplayList();
			_inner.invalidateDisplayList();
			init();
			//getEventStreamData();		
			loadSWF();// new addition , path and ppt name will now come from the html file.
		}
		
		private function onSlideSelected(e:WowzaCustomEvent):void
		{
			var slide1:int = SlideArray.length - int(e.eventObj.slide);
			var slide:int = int(Number(SlideArray[slide1][2]) - 1);
			var time:Number = Number(SlideArray[slide1][0]);
			_player.currentTime = time;
		}
		
		private function onSlideChanged(e:SlideEvent):void
		{
			changeSlide(e.slideNo);
		}
		
		private function onDataEvent(e:Event):void
		{
			trace("Data event : "+e.toString());
		}
		
		private function getEventStreamData():void
		{
			//_debugLab.text = "Loadeding event stream data";
			var urlLoader:URLLoader = new URLLoader();
			urlLoader.addEventListener(Event.COMPLETE, onEventStreamData);
			
			urlLoader.load(new URLRequest(_path+"/eventstreamData.xml"));
			
			/*
			var file:File = File.applicationDirectory.resolvePath("assets/eventStreamData.xml");
			
			// open and “READ” the content of the file
			var fileStream:FileStream = new FileStream();
			fileStream.open(file, FileMode.READ);
			var fileContent:String = fileStream.readUTFBytes(fileStream.bytesAvailable);
			fileStream.close();*/
			
			
			//urlLoader.load(new URLRequest("app:/assets/eventstreamdata.xml"));
			//urlLoader.addEventListener(Event.COMPLETE,OnEventDataComplete);
			//OnEventDataComplete(fileContent)
			
		}
		
		private function onEventStreamData(e:Event):void
		{	
			var xm:XML = new XML(e.target.data.toString());
			var nodeStr:String = xm.PresentationURL.toString()
			OnEventDataComplete(nodeStr)
		}
		
		private function OnEventDataComplete(dataStr:String):void
		{			
			_pptName = "";
			_pptName = dataStr;
			loadSWF();
			//loadXML();
			//init();
		}
		
		private function onImageLoad(e:Event):void
		{
			
		}
		private function onImageLoadError(e:ErrorEvent):void
		{
			
		}
		
		private function videoPlayer_metadataReceived(e:MetadataEvent):void
		{
			
		}
		
		
		private function init():void
		{
			cuePoints_array=new Array();
			parameters_array=new Array();
			//loadXML();
		}
		
		private function loadSWF():void
		{
			initPlayerAndSlide();
		}
		
		
		private function Progress(e:Event):void
		{
			var loadedByte:int = int(e.target.bytesLoaded);
			var totleBytes:int = int(e.target.bytesTotal);
			var per:int=Math.floor(loadedByte/totleBytes*100);
		}
		
		private function initPlayerAndSlide():void
		{
			slideImage.name = "slides";
			//var file:File = File.applicationDirectory.resolvePath("assets/presentations/"+_pptName+"/s1001.jpg");
			
			//slideImage.source = slideLocationPath+"/s1001.jpg";
		
			var str:String = _path + "/presentations/"+_pptName+"/s1001.jpg";
			
			slideImage.source = str;
		
			
			/*var filestream:FileStream = new FileStream();
			var bytes:ByteArray = new ByteArray()
			
			filestream.open(file, FileMode.READ);
			filestream.readBytes(bytes, 0, filestream.bytesAvailable);
			filestream.close();
			
		
			
			loader = new Loader();
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE, showPic);
			loader.loadBytes(bytes);*/
			
			_slideConta.addElement(slideImage);
			_slideConta.invalidateDisplayList();
		/*	slideImage.width = 880;
			
			slideImage.height = 380;
			//slideImage.scaleX = 1.2;
			//slideImage.scaleY = 1.2;

			slideImage.x = -150;
		*/
			
			 
			//var filepath:String = "file://" + File.applicationDirectory.nativePath + "/assets/test.mp4";
			if(_slideshow)
			{
				_slideshow.initSlides(_pptName,SlideArray.length);
			}
			_callback("");
			addingListener();
			_player.invalidateDisplayList();
			setPPTHori();
		}
		
		
		private function showPic(e:Event):void
		{
			loader.contentLoaderInfo.removeEventListener(Event.COMPLETE, showPic);
			var bitmapData:BitmapData = new BitmapData(loader.content.width,loader.content.height, true, 0x000000);
			bitmapData.draw(loader.content, new Matrix,null,null,null,true);
			slideImage.source = new Bitmap(bitmapData);
		}
		
		
		public function setPPTHori():void
		{
			if(isHD)
			{
				slideImage.height = 250;
				slideImage.width= 375;
				/*slideImage.x = 50;
				slideImage.y = 25;*/
			}
			else if(_isFullHD)
			{
				slideImage.height = 700;
				slideImage.width= 450;
				slideImage.x = 50;
				slideImage.y = 25;
			}
			else
			{
				slideImage.height = 250;
				slideImage.width= 375;
				slideImage.x = 50;
				slideImage.y = 25;
			}
			_player.setPPTHori();
		}
		
		public function setPPTVerti():void
		{
			slideImage.height = 200;
			slideImage.width= 325;
			slideImage.height = 200;
			slideImage.width = 325;
			slideImage.x = 0;
			slideImage.y = 0;
			
			slideImage.width = 440;
			
			slideImage.height = 170;
			//slideImage.scaleX = 1.2;
			//slideImage.scaleY = 1.2;
			
			slideImage.x = -70;
			_player.setPPTVerti();
		}
		
		private function addingListener():void
		{
			//StageRef.player.addEventListener(MetadataEvent.CUE_POINT,go);
			if(_live == false)
			{
				addEventListener(Event.ENTER_FRAME,currentTimeArchive);//StageRef.player.play()
			}
			
		}
		
		public function changeSlide(_newSlide:int):void
		{
			var CurrentPosition:Number = _player.currentTime;
			if (!isNaN(CurrentPosition))
			{
				if(_newSlide < 10)
				{
					var str:String = _path + "/presentations/"+_pptName+"/s100"+_newSlide+".jpg";
					slideImage.source = str;
					//_player.lab.text = slideLocationPath+"/s100"+slide+".jpg";
				}
				else
				{
					var file2:String = _path+"presentations/"+_pptName+"/s10"+_newSlide+".jpg";
					slideImage.source = file2;
				}
			}
		}
		
		private function currentTimeArchive(e:Event):void
		{
			var CurrentPosition:Number = _player.currentTime;
			if (!isNaN(CurrentPosition))
			{
				//myTrace(CurrentPosition+" : "+PresentationURL+" : "+CurrentSlide);
				for (var SlideIndex:Number = 0; SlideIndex < SlideArray.length; SlideIndex++)
				{
					//_player.lab.text = "CurrentPosition : "+CurrentPosition+"SetSlide"+SlideArray[SlideIndex][0]+" : "+SlideArray[SlideIndex][2];
					//_player.lab.text = _player.currentTime.toString();
					if (Number(SlideArray[SlideIndex][0]) <= CurrentPosition)
					{
						//_player.lab.text = _player.currentTime.toString();
						if (slideImage!=null)
						{
							var slide:int = int(Number(SlideArray[SlideIndex][2]) - 1);
							//_player.lab.text = slide.toString();
							//_player.lab.text =slideLocationPath+"/s100"+slide+".jpg";
							if(slide < 10)
							{
								//slideImage.source = slideLocationPath+"/s100"+slide+".jpg";
								//var file:File = File.applicationDirectory.resolvePath("assets/presentations/"+_pptName+"/s100"+slide+".jpg");
								//slideImage.source = file.url;
								var str:String = _path + "/presentations/"+_pptName+"/s100"+slide+".jpg";
								slideImage.source = str;
								trace("Time : "+CurrentPosition+" and lside : "+slide);
								//_player.lab.text = slideLocationPath+"/s100"+slide+".jpg";
							}
							else
							{
								//slideImage.source = slideLocationPath+"/s10"+slide+".jpg";
								//var file2:File = File.applicationDirectory.resolvePath("assets/presentations/"+_pptName+"/s10"+slide+".jpg");
								//slideImage.source = file2.url;
								var file2:String = _path+"presentations/"+_pptName+"/s10"+slide+".jpg";
								slideImage.source = file2;
								trace("Time : "+CurrentPosition+" and lside 10 : "+slide);
								//_player.lab.text = slideLocationPath+"/s10"+slide+".jpg";
							}
							
						}
						return;
					}
				}
				return;
			}
		}
		
		private function loadXML():void
		{
			/*var loader:URLLoader=new URLLoader();
			loader.addEventListener(Event.COMPLETE,completeHandler);
			var request:URLRequest=new URLRequest(_playlistUrl);
			loader.addEventListener(IOErrorEvent.IO_ERROR,onErrorIO);
			try 
			{
				loader.load(request);
			} 
			catch(error:Error) 
			{
			}*/
			
			//_debugLab.text = "Loadeding playlist data";
			var urlLoader:URLLoader = new URLLoader();
			//urlLoader.load(new URLRequest(_path+"/eventstreamdata.xml"));
			
			
			var file:File = File.applicationDirectory.resolvePath("assets/playlist.xml");
			
			// open and “READ” the content of the file
			var fileStream:FileStream = new FileStream();
			fileStream.open(file, FileMode.READ);
			var fileContent:String = fileStream.readUTFBytes(fileStream.bytesAvailable);
			fileStream.close();
			
			
			//urlLoader.load(new URLRequest("app:/assets/eventstreamdata.xml"));
			//urlLoader.addEventListener(Event.COMPLETE,OnEventDataComplete);
			completeHandler(fileContent)
		}
		
		private function onErrorIO(e:IOErrorEvent):void
		{
			trace(e.text);
		}
		
		private function completeHandler(dataStr:String):void
		{
			trace("playlistloaded");
			var tmpStr:String;
			var timeStr:int;
			//trace(e.target.data);
			var m_playlistXML:XML = new XML(dataStr);
			for (var i:int = 0; i<m_playlistXML.Scripts.Script.length(); i++){
				if (m_playlistXML.Scripts.Script[i].@Type == "URL")
				{
					tmpStr = m_playlistXML.Scripts.Script[i].@Command;
					timeStr = parseInt(m_playlistXML.Scripts.Script[i].@Time) / 10000000;
					tmpStr = tmpStr.replace("&&","^");
					tmpStr = timeStr + "^" + tmpStr;
					//trace(tmpStr);
					SlideArray.push(tmpStr.split("^"));
				}
			}
			//trace(SlideArray);
			SlideArray.reverse();
			loadSWF();
		}
		
		private function getClosestCuePoint(cuePoints:Array,time:Number):Object
		{
			var numCuePoints:Number = cuePoints.length;
			var minDist:Number = 100,result:Object;
			for (var i:Number = 0; i < numCuePoints; i++)
			{
				if (cuePoints[i].time  < time)
				{
					minDist =cuePoints[i].time;
					
					result = cuePoints[i];
				}
			}
			
			return result;
		}
		
		public function get isFullHD():Boolean
		{
			return _isFullHD;
		}
		
		public function set isFullHD(value:Boolean):void
		{
			_isFullHD = value;
		}
	
		
		public function get isHD():Boolean
		{
			return _isHD;
		}
		
		public function set isHD(value:Boolean):void
		{
			_isHD = value;
		}
		
	}
}// ActionScript file