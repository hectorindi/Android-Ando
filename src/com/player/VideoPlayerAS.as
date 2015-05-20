/* Contact info: Jordan: jordana309@byu.net between 2010 and 2015. */  

/* The built-in video display object would not work for our purposes, because it would leak enormous amounts of memory (in the order of 200-300MB) every time a new 
* video was loaded in and played. It was almost as though it retained all previous videos played in memory, rather than replacing the video it had loaded. 
* After farther investigation, I believe it had to do with the fact that s:VideoDisplay discards the source and videoGateway, and creates a new one, meaning that 
* garbage collection has to get in there and fix it. However it doesn't unless RAM is also being lost in enough little chunks, so...it never cleaned up. 
* This is the first attempt to fix that, by directly manipulating the netStream, and streaming the video, rather than loading it in as was happening in s:VideoDisplay. 
* I have, however, followed the structure that was presented in s:VideoDisplay provided by Adobe in the Flex 4.0.1 framework as far as where events and public functions 
* and so forth are declared. This video player uses a lot of code and ideas from s:VideoDisplay and the player described at 
* http://www.flashwebdesigns.com.au/index.php/2010/07/custom-flex-4-spark-videodisplay. More details of what this actually is found right above the constructor. */  

/* TODO: Looping pauses for a moment before restarting. 
*/  
package com.player  
{  
	/* Imports: 
	* NetStatusEvent is used to react to specific events in the video stream. For example, when it starts to play, when it stops, and so forth. 
	* SoundTransform is a class used to control the volume in the NetStream, and so when the volume is changed, we need to use this to create a new sound handler for the 
	stream. 
	* Video is used as the gateway through which the NetStream is visible. That is actually it's only purpose, because we wind up directly manipulating the NetStream when 
	we need to do anything with the video. 
	* NetConnection is used to initiate our NetStream. NetConnection is looking for a server connection. When we pass through null as the server, it knows we're after 
	local content. 
	* NetStream is what actually plays the videos off the computer. This is the central piece of this component. Using this class as our primary piece of this component 
	is what allows us to circumvent memory leaks and other issues. 
	* UIComponent is what this component extends, so it's needed for the basis of our component. 
	* FlexEvent is required to allow us to listen for creation complete, allowing us to call an init() function here like we do with almost every other component we have. 
	* TimeEvent was the original type of event used in s:VideoDisplay, so working on changing as little as possible, we kept that as our event types, and by the time we 
	finished, there was no point to changing it. */  
	
	import flash.events.Event;  
	import flash.events.NetStatusEvent;  
	import flash.media.SoundTransform;  
	import flash.media.Video;  
	import flash.net.NetConnection;  
	import flash.net.NetStream;  
	
	import mx.core.UIComponent;  
	import mx.events.FlexEvent;  
	
	import org.osmf.events.TimeEvent;  
	
	/* Events */  
	
	/* complete is dispatched when the playhead reaches the duration for playable media. 
	* original eventType: org.osmf.events.TimeEvent.COMPLETE */  
	[Event(name="complete", type="org.osmf.events.TimeEvent")]  
	/* durationChange is dispatched when the duration property of the media has changed. 
	* This event may not be dispatched when the source is set to null or a playback error occurs. 
	* original eventType: org.osmf.events.TimeEvent.DURATION_CHANGE */  
	[Event(name="durationChange", type="org.osmf.events.TimeEvent")]  
	/* needToSeek is dispatched whenever play() is called. play() loads in the new video. If the video is the same one that was already playing, therefore not changing the 
	* duration, we need to catch that, and the easiest way to do that is just to dispatch an event commanding that we seek. */  
	[Event(name="needToSeek", type="flash.events.Event")]  
	
	/* Explanation of component: VideoDislplayCustom is a replacement for s:VideoDisplay, since our method of loading in videos caused memory leaks in the order of hundreds 
	* of megabytes each time a new video was loaded in. This one provides a simple video playing object that attaches to a netStream, which we use 
	* to stream the video files off the hard driver rather than loading them into the player. By disallowing caching of any kind, we overcome memory leaks of 
	* that magnitute, and provide a tool that can last all day switching between videos often. */  
	
	public class VideoPlayerAS extends UIComponent  
	{  
		/* Constructor */  
		public function VideoPlayerAS()  
		{  
			super();  
			// We want to have an init() function, so we listen for it's dispatch.  
			this.addEventListener(FlexEvent.CREATION_COMPLETE, init);  
			// We build the actual stuff that plays our videos.  
			createUnderlyingVideoPlayer();  
			// The next three lines ensures that code farther down will work. We compare durations in vidInfo, which is just an array, so we first need to give it a duration  
			// value to compare (it's bad if we compare null to a number)  
			var tempArray:Array = new Array();  
			tempArray["duration"] = 0;  
			vidInfo = tempArray;  
		}  
		
		/* We need to allow everything time to initialize before we start trying create some things or addressing parts of some components. Looking towards expandability, 
		* also, this only makes sense to have. 
		* Called from: this.Creation_Complete, which event is fired after this component is all put together. */  
		private function init(event:FlexEvent):void  
		{  
			// since we added the event listener, we need to pull it off.  
			this.removeEventListener(FlexEvent.CREATION_COMPLETE, init);  
			videoPlayer.visible = true;  
		}  
		
		/* Global variables */  
		
		// Define our constants \\  
		
		// Time to buffer, in seconds, before it begins playback. Later assigned to the NetStream object. Since all our files loaded are on the local host, we  
		// don't need to set this very high. And if we use a black screen, we can specify a minimum buffer size.  
		protected const BUFFER_TIME:Number = 8;  
		
		// Public variables \\  
		
		// Holds the start volume when the player starts, defined in terms of percentage of total system volume.  
		public var defaultVolume:Number = .50;  
		// For when we mute, we need to save the previous volume. This wil let us double-check with our dropDown component or other components to make sure that  
		// we have the right "lastVolume".  
		public var lastVolume:Number = defaultVolume;  
		// When we mute our video, we need to know it's muted. Checking to see if it the volume is 0 is not accurate enough, so we have a variable for it. Also,  
		// the s:VideoDisplay uses a "muted" variable, and since we want to keep it looking the same from the outside as this component, we keep that variable.  
		public var muted:Boolean = false;  
		// When we want to loop the video, we need to know that, so here's our loop boolean. Basically, when we hit the end of the video playing, either we issue  
		// a "complete" event, or we start playing it again from the beginning. This boolean determines which.  
		public var loop:Boolean = false;  
		// We need to know if we can smooth the video or not (to improve playback quality). Also something from s:VideoDisplay  
		public var smoothing:Boolean = true;  
		// We needed a way to carry through the height and width, and for some reason, this.width and this.height were both cleared and reset to 0 before the component is  
		// created, or sometime during creation, so we needed to create these variables instead to carry it through. Breaks our "looking the same from outside" attempt.  
		public var playerWidth:Number = 1024;  
		public var playerHeight:Number = 768;  
		
		// Private and protected variables \\  
		
		// We need to be able to define a source for our video player. This would be a public variable, but that wasn't allowing for both playing the first video and the  
		// subsiquant subclips, so we had to write getter and setter functions for the source, so we can maintain the previous source to know how to act. Thus, we have  
		// our newSource and our oldSource.  
		protected var newSource:String = "";  
		// We also need to know if we have a new source loaded in, so this variable holds the old source.  
		protected var oldSource:String = "";  
		// We need a video object to attach the NetStream to. So, here that is.  
		protected var videoPlayer:Video;  
		// We need to have a NetStream to be able to use it, and to create one, we need to have a NetConnection. So, here they are.  
		protected var netConnection:NetConnection;  
		protected var netStream:NetStream;  
		// We need to store the metadata for the video that we load up, so here's our metadata storing object.  
		protected var vidInfo:Object;  
		
		/* Meathods of this component (aka public functions), visible to the whole program. */  
		
		/* This function checks our sources, and if they haven't actually changed, we don't want to reload the stream, so we just tell the hosing component (which for 
		* us is the VideoScreenCustom component) that we need to seek. If we load in the new video (netStream.play(newSource), then we can't seek until the video is 
		* actually loaded, and we can't always seek from the onMetaData functions below, so this seemed the best way to do it. 
		* Called from: play() and playScreenSaver() in VideoScreenCustom.mxml. */  
		public function play():void  
		{  
			if(newSource == oldSource)  
			{  
				dispatchNeedToSeek();  
			} else {  
				netStream.play(newSource);  
			}  
		}  
		
		/* Pretty straightforward--we pause the video by pausing the netStream.  
		* Called from: pause() in VideoScreenCustom.mxml. */  
		public function pause():void  
		{  
			netStream.pause();  
		}  
		
		/* Pretty straightforward--we need to unpause the video where we left off, so we call resume() on the netStream to unpause.  
		* Called from: resume() in VideoScreenCustom.mxml. */  
		public function resume():void  
		{  
			netStream.resume();  
		}  
		
		/* We don't currently use this, because closing the netStream makes it hard to restart videos and seek, since it's still opening the stream when the seek command 
		* is sent, and it stops the screen saver from working properly. It's just best to avoid closing our stream unless we are unloading it or something. 
		* Called from: nowhere. This is a place holder / view into other uses. */  
		public function stop():void  
		{  
			netStream.pause();  
			netStream.close();  
		}  
		
		/* We need to be able to move around a video and to enter at different entryPoints, so seeking is vital. Here, we make it accessable from outside this component. 
		* Called from: loopVideo() in this component, play(), rewindVideo() and fastForwardVideo(), and seekToPoint() from VideoScreenCustom.mxml */  
		public function seek(timeToSeekTo:Number):void  
		{  
			netStream.seek(timeToSeekTo);  
		}  
		
		/* Function that mutes the video. When it is called again, it restores the previous volume. 
		* Called from: set volume() below, and currently nowhere else. This is a place holder until that feature is requested. */  
		public function mute():void  
		{  
			if(!muted)  
			{  
				lastVolume = netStream.soundTransform.volume;  
				setVolume(0);  
				muted = true;  
			} else {  
				setVolume(lastVolume);  
				muted = false;  
			}  
		}  
		
		/* Getter and setter functions */  
		
		/* Used by VideoScreenCustom to know what the current time in the video is so that it can rewind, fastforward (by passing through a new time to seek to), and so 
		* we can watch for stop points in the video clips. */  
		public function get currentTime():Number  
		{  
			return netStream.time;  
		}  
		
		/* Used by the videoScreenCustom to know if it is even possible to fast forward any (if within the skip interval from the end, then FFing is not possible). Also 
		* here if ever needed for any other reason. */  
		public function get duration():Number  
		{  
			return vidInfo.duration;  
		}  
		
		/* Since we're remembering both the previous and the current source, we need to specify that we are returning the newSource through this getter function. 
		* Externally, this looks just like a public variable. */  
		public function get source():String  
		{  
			return newSource;  
		}  
		
		/* Since we remember both the old and the current source, when the source is changed (.source = "somePath"), we need to copy the current source, then set the new 
		* one so that we can use it in this to know whether to load the video or not (we don't want to load it if it is already loaded in and playing). Externally, this 
		* looks just like a public variable.*/  
		public function set source(sourceToSet:String):void  
		{  
			oldSource = newSource;  
			newSource = sourceToSet;  
		}  
		
		/* From videoScreenCustom, we set the volume only through videoDisplay.volume=NUM. So, we handle all volume stuff here. It is possible to have the videoScreen 
		* call mute() seperately in the future, so we add a little logic here to unmute if muted. Otherwise, we se the volume. */  
		public function set volume(volumeToSet:Number):void  
		{  
			if(muted)  
			{  
				mute();  
			} else {  
				setVolume(volumeToSet);       
			}  
		}  
		
		/* We store the metadata information gathered by the NetStream object, so that we can get to it later in this program. This isn't truly a meathod (meaning available 
		* to the component hosting this one), but it had to be made public so that the NetStream object could find it. You'll note that we have too onSomeDate() functions. 
		* The reason for that is that some video conatiners return one type of data (MetaData), and another returns a different set of metadata (XMPData). 
		* Called from: NetStream object, as soon as it gets the metadata and information from the loaded file. */  
		public function onMetaData(info:Object):void  
		{  
			var oldVidInfo:Number = vidInfo.duration;  
			vidInfo = info;  
			if(oldVidInfo != vidInfo.duration)  
			{  
				dispatchDurationChange();  
			}  
			resizeVideo();  
		}  
		
		/*See above on onMetaData() for info about this. It does the same thing, but for different file formats (mostly flash-based containers). */  
		public function onXMPData(info:Object):void  
		{  
			var oldVidInfo:Number = vidInfo.duration;  
			vidInfo = info;  
			if(oldVidInfo != vidInfo.duration)  
			{  
				dispatchDurationChange();  
			}  
			resizeVideo();  
		}  
		
		/* Private and protected functions of this component, closed off to the rest of the program. */  
		
		/* We need to build the essential pieces of the player and leave them in all the time. The basic concept for this player is that we have a Video object to 
		* serve as a gateway for the NetStream object, which is what actually connects to the video file and passes it through. The Video object is just the reciever-- 
		* that means that all calls and commands that we want to deliver to the playing video we instead direct towards to NetStream. 
		* Called from: the constructor function. */  
		protected function createUnderlyingVideoPlayer():void  
		{  
			// create our Video object, attach it to the stage, and resize it (critical--since otherwise, both height and width would be 0).  
			videoPlayer = new Video();  
			addChild(videoPlayer);  
			videoPlayer.width = playerWidth;  
			videoPlayer.height = playerWidth;  
			
			// NetConnection is needed to open the NetStream. When anything changes in this stream, we can handle those changes in netStatusHandler(). When we connect and  
			// pass through null, it means that we have no server and the files will be hosted on the local box.  
			netConnection = new NetConnection();  
			netConnection.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);  
			netConnection.connect(null);  
			
			// The main piece. Through this netStream, we control video playback, volume, and so forth.  
			netStream = new NetStream(netConnection);  
			netStream.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);  
			// the client is who the NetStream turns to to find functions for it's events. There is one event that requires handling--the one that calls onMetaData  
			// (or MXPData). It finds those functions in the client object.   
			netStream.client = this;  
			// How long it will buffer before it starts to play the video. Since we're on the local box, our buffer can pretty much be as low as we want.  
			netStream.bufferTime = BUFFER_TIME;  
			
			setVolume(defaultVolume);  
			// Final step: attach the NetStream object to the Video so that the Video knows to pay attention and do something.  
			videoPlayer.attachNetStream(netStream);  
		}  
		
		/* We need to change the size of the video to fit on the screen. However, it must be noted that sometimes, if it must be stretched too far, then video quality 
		* becomes horrible, and so far, no workaround has been discovered. 
		* Called from: onMetaData (of all kinds, including XMP and other types of metadata), called whenever a new video is loaded in. */  
		protected function resizeVideo():void  
		{  
			videoPlayer.width = playerWidth;  
			videoPlayer.height = ((playerWidth * vidInfo.height) / vidInfo.width);  
			videoPlayer.x = 0;  
			videoPlayer.y = ((playerHeight - videoPlayer.height) / 2);  
		}  
		
		/* In order to change the volume, we have to apply a new soundTransform object. So, here we create it and do that. 
		* Called from: mute(), createUnderlyingVideoPlayer(), and the setter function set volume(). */  
		protected function setVolume(volumeToSet:Number):void  
		{  
			var soundTransform:SoundTransform = new SoundTransform(volumeToSet);  
			netStream.soundTransform = soundTransform;  
		}  
		
		/* For our screensaver, we needed to allow the video to loop. This function will handle that. The only problem is, since we wait for it to .Stop (see Called from:), 
		* there is a pause between the end of the video, and when it starts over. 
		* Called from: netStatusHandler for NetStream.Play.Stop */  
		protected function loopVideo():void  
		{  
			netStream.seek(0);  
		}  
		
		/* We need to pay attention to what the NetStream is saying and react accordingly. Especially when the video ends. All NetStream andNetConnection events on 
		* documentation at Adobe are listed as a comment at the end of the class (very end of this file). 
		* Called from: the NetStream and NetConnection event when they spit out an event. */  
		protected function netStatusHandler(event:NetStatusEvent):void  
		{  
			switch (event.info.code)  
			{  
				case "NetStream.Play.StreamNotFound":  
					trace("Error. Stream not found: " + source);  
					break;  
				case "NetStream.Play.Stop":  
					if(loop)  
					{  
						loopVideo();  
					} else {  
						var playedTime:Number = int(netStream.time);  
						var totalTime:Number = int(vidInfo.duration);  
						// if we're within 2 seconds of the end, assume we're at the end.  
						if(Math.abs(totalTime - playedTime) <= 1)  
						{  
							dispatchComplete();  
						}  
					}  
					break;  
			}  
		}  
		
		/* Event Dispatching Functions */  
		
		/* Sent out to let the hosting component (VideoScreenCustom) know that the end of the video clip has been reached. 
		* Called from: NetStream's NetStream.Play.Stop event code, sent out whenever the end of the video playing through the stream is reached. */  
		protected function dispatchComplete():void  
		{  
			var eventObj:TimeEvent = new TimeEvent("complete");  
			dispatchEvent(eventObj);  
		}  
		
		/* When the new and old sources have different durations (meaning a new video has been loaded), this is called to let the hosing component know we have a new vid. 
		* Called from: onMetaData (onXMPData), which is called whenever a video is loaded. */  
		protected function dispatchDurationChange():void  
		{  
			var eventObj:TimeEvent = new TimeEvent("durationChange");  
			dispatchEvent(eventObj);  
		}  
		
		/* When we don't have a new video, we still need to call seek() after the NetStream is aware that the video is the same. Or something. I'm not sure why, but we need 
		* to seek after things have been set and run for a few microseconds. This is used for FFing, RRing, but mostly for seeking to a new "chapter" in a continuous 
		* video during playback. 
		* Called from: play() above. */  
		protected function dispatchNeedToSeek():void  
		{  
			var eventObj:Event = new Event("needToSeek");  
			dispatchEvent(eventObj);  
		}  
		
	}  
}  

/* 
The following table describes the possible string values of the code and level properties. 
Code property Level property Meaning  
"NetStream.Play.Start" "status" Playback has started.  
"NetStream.Play.Stop" "status" Playback has stopped.  
"NetStream.Play.Failed" "error" An error has occurred in playback for a reason other than those listed elsewhere in this table, such as the subscriber not having read access.  
"NetStream.Play.StreamNotFound" "error" The FLV passed to the play() method can't be found.  
"NetStream.Play.Reset" "status" Caused by a play list reset.  
"NetStream.Play.PublishNotify" "status" The initial publish to a stream is sent to all subscribers.  
"NetStream.Play.UnpublishNotify" "status" An unpublish from a stream is sent to all subscribers.  
"NetStream.Play.InsufficientBW"  "warning" Flash Media Server only. The client does not have sufficient bandwidth to play the data at normal speed.   
"NetStream.Play.FileStructureInvalid" "error" The application detects an invalid file structure and will not try to play this type of file. For AIR and for Flash Player 9.0.115.0 and later.  
"NetStream.Play.NoSupportedTrackFound" "error" The application does not detect any supported tracks (video, audio or data) and will not try to play the file. For AIR and for Flash Player 9.0.115.0 and later.  
"NetStream.Play.Transition" "status" Flash Media Server only. The stream transitions to another as a result of bitrate stream switching. This code indicates a success status event for the NetStream.play2() call to initiate a stream switch. If the switch does not succeed, the server sends a NetStream.Play.Failed event instead. For Flash Player 10 and later.  
"NetStream.Play.Transition" "status" Flash Media Server 3.5 and later only. The server received the command to transition to another stream as a result of bitrate stream switching. This code indicates a success status event for the NetStream.play2() call to initiate a stream switch. If the switch does not succeed, the server sends a NetStream.Play.Failed event instead. When the stream switch occurs, an onPlayStatus event with a code of "NetStream.Play.TransitionComplete" is dispatched. For Flash Player 10 and later.  
"NetStream.Pause.Notify" "status" The stream is paused.  
"NetStream.Unpause.Notify" "status" The stream is resumed.  
"NetStream.Record.Start" "status" Recording has started.  
"NetStream.Record.NoAccess" "error" Attempt to record a stream that is still playing or the client has no access right.  
"NetStream.Record.Stop" "status" Recording stopped.  
"NetStream.Record.Failed" "error" An attempt to record a stream failed.  
"NetStream.Seek.Failed" "error" The seek fails, which happens if the stream is not seekable.  
"NetStream.Seek.InvalidTime" "error" For video downloaded with progressive download, the user has tried to seek or play past the end of the video data that has downloaded thus far, or past the end of the video once the entire file has downloaded. The message.details property contains a time code that indicates the last valid position to which the user can seek.  
"NetStream.Seek.Notify" "status" The seek operation is complete.  
"NetConnection.Call.BadVersion" "error" Packet encoded in an unidentified format.  
"NetConnection.Call.Failed" "error" The NetConnection.call method was not able to invoke the server-side method or command.  
"NetConnection.Call.Prohibited" "error" An Action Message Format (AMF) operation is prevented for security reasons. Either the AMF URL is not in the same domain as the file containing the code calling the NetConnection.call() method, or the AMF server does not have a policy file that trusts the domain of the the file containing the code calling the NetConnection.call() method.   
"NetConnection.Connect.Closed" "status" The connection was closed successfully.  
"NetConnection.Connect.Failed" "error" The connection attempt failed.  
"NetConnection.Connect.Success" "status" The connection attempt succeeded.  
"NetConnection.Connect.Rejected" "error" The connection attempt did not have permission to access the application.  
"NetStream.Connect.Closed" "status" The P2P connection was closed successfully. The info.stream property indicates which stream has closed.  
"NetStream.Connect.Failed" "error" The P2P connection attempt failed. The info.stream property indicates which stream has failed.  
"NetStream.Connect.Success" "status" The P2P connection attempt succeeded. The info.stream property indicates which stream has succeeded.  
"NetStream.Connect.Rejected" "error" The P2P connection attempt did not have permission to access the other peer. The info.stream property indicates which stream was rejected.  
"NetConnection.Connect.AppShutdown" "error" The specified application is shutting down.  
"NetConnection.Connect.InvalidApp" "error" The application name specified during connect is invalid.  
"SharedObject.Flush.Success" "status" The "pending" status is resolved and the SharedObject.flush() call succeeded.  
"SharedObject.Flush.Failed" "error" The "pending" status is resolved, but the SharedObject.flush() failed.  
"SharedObject.BadPersistence" "error" A request was made for a shared object with persistence flags, but the request cannot be granted because the object has already been created with different flags.  
"SharedObject.UriMismatch" "error" An attempt was made to connect to a NetConnection object that has a different URI (URL) than the shared object.  

If you consistently see errors regarding the buffer, try changing the buffer using the NetStream.bufferTime property. 

*/  // ActionScript file