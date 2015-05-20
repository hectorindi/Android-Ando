package com.player
{
	import flash.events.Event;
	
	public class SlideEvent extends Event
	{
		
		public var  slideNo:int = 0;
		public static var  SLIDE_CHNAGED:String = "SlideChannged";
		
		public function SlideEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
		}
	}
}