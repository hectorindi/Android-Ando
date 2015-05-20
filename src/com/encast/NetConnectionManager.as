﻿/*
<AUTHOR: Jake Hilton, jake@gearsandcogs.com
Copyright (C) 2010, Gears and Cogs.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

VERSION: 1.0.8
DATE: 8/29/2013
ACTIONSCRIPT VERSION: 3.0
DESCRIPTION:
A replacement class for the standard NetConnection actionscript class. This easily enables multiple port attempts to resolve at the best functioning port.

Used to connect quickly through firewalls by trying a NetConnection via a shotgun connection approach or an incremental connection approach.

Possible protocol attempts: rtmp,rtmpt,rtmpe,rtmpte,rtmps, and rtmfp.

It does have a few properties listed below that can be set before the connect call is made.

append_guid: a boolean to enable a unique GUID be placed at the end of the parameters argument passed into the connect method.  
This can be used to identify which connection requests are coming from the same client and that can be ignored if one is already being processed.
recreate_guid: a boolean to enable the recreation of the GUID each time the main connect method is called. By default this is false.
auto_reconnect: a boolean to enable or dispable automatic reconnect attempts. By default this is set to false.
connection_rate: only applicable if using a non-shotgun approach. Sets the rate that connections are tried. By default this is 200ms
debug: if you want to see debug messages via your trace panel
enctyped: used if you want to force the use of an encrypted connection (rtmp(t)e)
force_tunneling: used if you don't ever want to attempt rtmp connections
skip_tunneling: used if you don't ever want to attempt rtmpt connections
reconnect_count_limit: specify the max amount of reconnect attempts are made. Default is 10.
shotgun_connect: a boolean to enable or disable the shotgun approach. By default it is enabled.
portArray: an array containing ports in the order they should be tried. By default is it [443,80,1935]

It has an event,MSG_EVT, that fires to notify the user of an event in the class.

If you are experiencing issues with proxies you can try setting the proxyType="best" as this will attempt to use a different connect method if normal attempts fail.

USAGE:
It's a simple use case really.. just use it as you would the built in NetConnection class. Just specify rtmp as the protocol and let
the class handle the rest whether to use rtmpt or rtmp. In the case of encrypted still only pass in rtmp and it will resolve to rtmpe or rtmpte.
The only caveat is that for netstreams you'd need to pass in a reference to the connection and not the main class.

It also supports rtmfp. Using this library will support auto-reconnect if needed as well as
some other hooks this lib buys. It would also be possible to switch between protocols using the same netconnectionsmart connection class.

For example:

var client_obj:Object = new Object();
client_obj.serverMethod = function(e:Object):void
{
trace("server can call this");
}

var ncs:NetConnectionSmart = new NetConnectionSmart();
ncs.client = client_obj;
ncs.encrypted = true; //if this isn't specified it will default to rtmp/rtmpt.. if true it will try rtmpe/rtmpte
ncs.connect("rtmp://myserver.com/application");

ncs.addEventListener(NetStatusEvent.NET_STATUS,function(e:NetStatusEvent):void
{
trace("connection status: "+e.info.code);
trace(ncs.uri);
trace(ncs.protocol);
});

var ns:NetStream = new NetStream(ncs.connection);

*/

package com.encast
{
	
	import flash.events.AsyncErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.NetStatusEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.NetConnection;
	import flash.net.ObjectEncoding;
	import flash.net.Responder;
	import flash.utils.Timer;
	
	public class NetConnectionManager extends EventDispatcher
	{
		public static const MSG_EVT								:String = "NetConnectionSmartMsgEvent";
		public static const VERSION								:String = "NetConnectionSmart v 1.0.8";
		
		public static const NETCONNECTION_CONNECT_CLOSED		:String = "NetConnection.Connect.Closed";
		public static const NETCONNECTION_CONNECT_FAILED		:String = "NetConnection.Connect.Failed";
		public static const NETCONNECTION_CONNECT_REJECTED		:String = "NetConnection.Connect.Rejected";
		public static const NETCONNECTION_CONNECT_SUCCESS		:String = "NetConnection.Connect.Success";
		
		public static const NETCONNECTION_RECONNECT_FAILED		:String = "NetConnection.Reconnect.Failed";
		public static const NETCONNECTION_RECONNECT_INIT		:String = "NetConnection.Reconnect.Init";
		
		private static const RTMFP								:String = "rtmfp";
		private static const RTMP								:String = "rtmp";
		private static const RTMPT								:String = "rtmpt";
		
		public var append_guid									:Boolean;
		public var auto_reconnect								:Boolean;
		public var default_port_only							:Boolean;
		public var debug										:Boolean = true;
		public var encrypted									:Boolean;
		public var force_tunneling								:Boolean;
		public var is_rtmfp										:Boolean;
		public var recreate_guid								:Boolean;
		public var secure										:Boolean;
		public var sequential_connect							:Boolean = true;
		public var shotgun_connect								:Boolean = false;
		public var skip_tunneling								:Boolean;
		
		public var connection_rate								:uint = 200;
		public var reconnect_count_limit						:uint = 10;
		
		private var _connect_params								:Array;
		private var _connect_params_init						:Array;
		private var _ncTypes									:Vector.<NetConnectionType>;
		private var _portArray									:Array = [80,443,1935];
		
		private var _initial_connect_run						:Boolean;
		private var _is_connecting								:Boolean;
		private var _was_connected								:Boolean;
		
		private var _nc_client									:Object;
		
		private var _nc											:PortConnection;
		
		private var _app_string									:String;
		private var _connect_string_init						:String;
		private var _encrypted_secure_string					:String;
		private var _guid										:String;
		private var _proxy_type									:String = "none";
		private var _server_string								:String;
		
		private var _connect_timer								:Timer;
		
		private var _connection_attempt_count					:uint;
		private var _object_encoding							:uint = ObjectEncoding.AMF3;
		private var _reconnect_count							:uint;
		
		public function NetConnectionManager()
		{
			_nc_client = new Object();
			_guid = GUID.create();
			//addEventListener(NetStatusEvent.NET_STATUS, onConnectionStatus);
			//addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
			//addEventListener(AsyncErrorEvent.ASYNC_ERROR, onAsyncError);
			//addEventListener(IOErrorEvent.IO_ERROR, onIOError);
		}
		
		protected function onConnectionStatus(event:NetStatusEvent):void{
			//trace("#onConnectionStatusEvent# " + event.info.code);
			//trace("uri: " + uri);
			
			var infoObjectsArray:Array = event.info.code.split(".");
			
			if (infoObjectsArray[1] == "Connect"){
				switch (infoObjectsArray[2]){
					case "Success":
						dispatchEvent(new NetStatusEvent("onConnect", false, false, event.info));
						break;
					case "Failed":
						dispatchEvent(new NetStatusEvent("onFailed", false, false, event.info));
						break;
					case "Rejected":
						dispatchEvent(new NetStatusEvent("onRejected", false, false, event.info));
						break;
					case "Closed":
						dispatchEvent(new NetStatusEvent("onClosed", false, false, event.info));
						break;
				}
			}
		}		
		
		protected function onSecurityError(event:SecurityErrorEvent):void{
			trace("#onSecurityError# " + event.text);
		}
		
		protected function onAsyncError(event:AsyncErrorEvent):void{
			trace("#onAsyncError# " + event.error.message);
		}
		
		
		protected function onIOError(event:IOErrorEvent):void{
			trace("#onIOError# " + event.text);
		}
		
		private function trace(msg:String):void
		{
			try
			{
				var msg1:String = '';
				msg1 = msg;
				if(msg1 != "" && msg1.length <100 && msg1.length > 0)
				{
					trace("## NETCONNECTIONMANAGER ## " + msg);
				}
			} catch (e:Error)
			{
				trace("error in trace");
			}
		}
		
		/**
		 * 
		 *public functions callable like the netconnection ones
		 *
		 */		
		
		public function call(command:String,responder:Responder=null,...parameters):void
		{
			if(!_nc || !_nc.connected)
				throw(new Error("NetConnection must be connected in order to make a call on it."));
			
			_nc.call.apply(null,[command,responder].concat(parameters));
		}
		
		public function connect(command:String, ...parameters):void
		{
			if(debug)
				log(VERSION);
			
			//check for null connection param
			if(command == null)
			{
				_nc = new PortConnection(0,"",debug);
				_nc.connect(null);
				return;
			}
			
			if(_is_connecting || connected)
				return;
			
			_is_connecting = true;
			
			//check for rtmfp connection
			is_rtmfp = command.substr(0,5).toLocaleLowerCase()=="rtmfp";
			
			//strip rtmp variants
			_connect_string_init = ~command.indexOf("://")?command.substring(command.indexOf("://")+3):command;
			
			//strip port declaration
			if(~_connect_string_init.indexOf(":"))
			{
				var split_connect:Array = _connect_string_init.split(":");
				_connect_string_init = split_connect[0]+split_connect[1].substring(split_connect[1].indexOf("/"));
			}
			
			//setting very low connection rate but helps to avoid race conditions serverside
			if(shotgun_connect)
				connection_rate = 100;
			
			//create new guid
			if(recreate_guid && _initial_connect_run)
				_guid = GUID.create();
			
			//if rtmfp we need to modify some values
			if(is_rtmfp)
				encrypted = false; // rtmfp is already encrypted so we don't need to append this flag
			
			initConnectionTypes();
			
			_connect_params_init = parameters;
			_connect_params = append_guid?parameters.concat(_guid):parameters;
			_server_string = _connect_string_init.substring(0,_connect_string_init.indexOf("/"));
			_app_string = _connect_string_init.substring(_connect_string_init.indexOf("/"));
			_encrypted_secure_string = encrypted?"e":secure?"s":"";
			_initial_connect_run = true;
			
			_nc = null;
			closeExtraNc();
			
			if(_server_string == "" || _app_string.length<2)
				throw(new Error("Invalid application path. Need server and application name"));
			
			if(_encrypted_secure_string=="s" && force_tunneling)
				throw(new Error("Secure connections cannot run over rtmpt. Either turn off force tunnelling or the secure flag."));
			
			if(sequential_connect)
				initConnection();
			else
				initializeTimers();
		}
		
		public function set client(obj:Object):void
		{
			_nc_client = obj;
		}
		
		public function get connected():Boolean
		{
			try{
				return _nc.connected;
			} catch(e:Error){}
			
			return false;
		}
		
		public function get connection():NetConnection
		{
			return _nc;
		}
		
		public function close(is_dirty:Boolean = false):void
		{
			if(!is_dirty)
				_was_connected = false;
			
			if(_nc)
				_nc.close();
			
			if(is_dirty)
				return;
			
			_nc = null;
			closeExtraNc();
		}
		
		public function get connectParams():Array
		{
			return _connect_params_init;
		}
		
		public function set connectParams(paramArray:Array):void
		{
			_connect_params_init = paramArray;
		}
		
		public function get guid():String
		{
			return _guid;
		}
		
		public function get objectEncoding():uint
		{
			return _nc?_nc.objectEncoding:_object_encoding;
		}
		
		public function set objectEncoding(encoding:uint):void
		{
			_object_encoding = encoding;
			if(_nc)
				_nc.objectEncoding = encoding;
		}
		
		public function get protocol():String
		{
			return _nc.uri.substring(0,_nc.uri.indexOf("://"));
		}
		
		public function get proxyType():String
		{
			return _nc.proxyType;
		}
		
		public function set proxyType(type:String):void
		{
			_proxy_type = type;
		}
		
		public function get connectedProxyType():String
		{
			return _nc.connectedProxyType;
		}
		
		public function get uri():String
		{
			return _nc.uri;
		}
		
		public function get usingTLS():Boolean
		{
			return _nc.usingTLS;
		}
		
		public function get portArray():Array
		{
			return _portArray;
		}
		
		public function set portArray(portArray:Array):void
		{
			_portArray = portArray;
			initConnectionTypes();
		}
		
		/**
		 * 
		 * private methods used to push things up the stack for listeners
		 * and to manage net connections
		 * 
		 */	
		
		private function acceptNc(portConnection:PortConnection):void
		{
			_nc = portConnection;
			
			_nc.removeEventListener(PortConnection.STATUS_UPDATE,checkNetStatus);
			_nc.removeHandlers();
			
			_nc.addEventListener(AsyncErrorEvent.ASYNC_ERROR,handleAsyncError);
			_nc.addEventListener(IOErrorEvent.IO_ERROR,handleIoError);
			_nc.addEventListener(NetStatusEvent.NET_STATUS,handleNetStatus);
			_nc.addEventListener(SecurityErrorEvent.SECURITY_ERROR,handleSecurityError);
			
			_nc.client = _nc_client;
			
			if(_connect_timer)
				_connect_timer.stop();
			
			closeExtraNc();
		}
		
		private function closeExtraNc():void
		{
			for each(var n:NetConnectionType in _ncTypes){
				var portConnection:PortConnection = n.connection;
				if(portConnection && portConnection != _nc)
				{
					closeDownNc(portConnection);
					n.connection = null;
				}
			}
		}
		
		private function closeDownNc(pc:PortConnection):void
		{
			if(debug)
				log("Closing down NetConnection: "+pc.label);
			
			pc.removeEventListener(PortConnection.STATUS_UPDATE,checkNetStatus);
			pc.addEventListener(NetStatusEvent.NET_STATUS,nullHandleNetStatus);
			pc.close();
			
			//cleanup listener
			pc.removeHandlers();
		}
		
		/**
		 * 
		 * @param netconnection
		 * @param protocol
		 * @param port
		 * @param parameters
		 * 
		 */		
		
		private function processConnection(connection:PortConnection,protocol:String,port:String, parameters:Array):void
		{
			if(default_port_only && port != "default")
				return;
			
			var portpass:String = port!="default"?":"+port:"";
			
			if(debug) 
				log("connecting to: "+protocol+_encrypted_secure_string+"://"+_server_string+portpass+_app_string);
			
			connection.connect.apply(null,[protocol+_encrypted_secure_string+"://"+
				_server_string+portpass+_app_string].concat(parameters));
		}
		
		private function initConnectionTypes():void
		{
			if(skip_tunneling && force_tunneling)
				throw(new Error("Cannot force tunneling and skip tunneling. Please choose one or the other."));
			
			_ncTypes = new Vector.<NetConnectionType>();
			for each(var r:String in _portArray)
			{
				if(is_rtmfp)
					_ncTypes.push(new NetConnectionType(RTMFP,r))
				else 
				{
					if(!force_tunneling)
						_ncTypes.unshift(new NetConnectionType(RTMP,r));
					if(!skip_tunneling && !secure)
						_ncTypes.push(new NetConnectionType(RTMPT,r))
				}
			}
		}
		
		private function initPortConnection(nc_num:uint):NetConnectionType
		{
			var encrypted_secure_identifier:String = encrypted?"Encrypted ":secure?"Secure ":"";
			
			var curr_nct:NetConnectionType = _ncTypes[nc_num];
			var port_label:String = encrypted_secure_identifier+curr_nct.protocol+" "+curr_nct.port;
			var curr_pc:PortConnection = new PortConnection(nc_num,port_label,debug);
			
			curr_pc.objectEncoding = _object_encoding;
			curr_pc.proxyType = _proxy_type;
			
			curr_pc.client = _nc_client;
			curr_pc.addEventListener(PortConnection.STATUS_UPDATE,checkNetStatus);
			curr_nct.connection = curr_pc;
			
			return curr_nct;
		}
		
		private function initializeTimers():void
		{
			if(debug)
				log("Connecting at a rate of: "+connection_rate);
			
			if(_connect_timer)
				_connect_timer.stop();
			
			_connect_timer = new Timer(connection_rate);
			_connect_timer.addEventListener(TimerEvent.TIMER,function(e:TimerEvent):void
			{
				initConnection(_connect_timer.currentCount-1);
			});
			
			_connect_timer.start();
		}
		
		private function initConnection(connect_count:uint=0):void
		{
			//all connection attempts have been tried
			if(connect_count >= _ncTypes.length)
			{
				if(_connect_timer)
					_connect_timer.stop();
				return;
			}
			
			_connection_attempt_count = connect_count;
			var curr_nct:NetConnectionType = initPortConnection(connect_count);
			
			if(!curr_nct.connection.status)
				processConnection(curr_nct.connection,curr_nct.protocol,curr_nct.port,_connect_params);
		}
		
		private function checkNetStatus(e:Event):void
		{
			var target_connection:PortConnection = e.target as PortConnection;
			
			if(debug)
				log(target_connection.label+": "+target_connection.status.info.code);
			
			var status_count:uint;
			var rejected_connection:PortConnection;
			
			for each(var i:NetConnectionType in _ncTypes)
			{
				var curr_connection:PortConnection = i.connection;
				
				if(!curr_connection)
					continue;
				
				if(curr_connection.status)
					status_count++;
				
				if(!connected && curr_connection.connected)
				{
					acceptNc(curr_connection);
					handleNetStatus(curr_connection.status);
					_is_connecting = false;
					_was_connected = true;
					_reconnect_count = 0;
					_connection_attempt_count = 0;
					return;
				} else if(!rejected_connection && curr_connection.rejected)
					rejected_connection = curr_connection;
			}
			
			//if no success at all return the first rejected message or
			//return the status of the first connection in the array
			if(status_count >= _ncTypes.length)
			{
				_is_connecting = false;
				
				if(!rejected_connection)
					handleNetStatus(_ncTypes[_ncTypes.length-1].connection.status);
				else
					handleNetStatus(rejected_connection.status);
			} else if(sequential_connect)
				initConnection(++_connection_attempt_count);
		}
		
		private function handleAsyncError(e:AsyncErrorEvent):void
		{
			if(debug) 
				log(e.error.toString());
			dispatchEvent(e);
		}
		
		private function handleIoError(e:IOErrorEvent):void
		{
			if(debug) 
				log(e.text);
			dispatchEvent(e);
		}
		
		private function nullHandleNetStatus(e:NetStatusEvent):void
		{
			if(debug) 
				log("null handler: "+e.info.code);
		}
		
		private function handleNetStatus(e:NetStatusEvent):void
		{
			if(debug && e.info && e.info.code) 
				log(e.info.code);
			
			dispatchEvent(e);
			
			if(!auto_reconnect || !_was_connected || (e.info.code != "NetConnection.Connect.Closed" && e.info.code != "NetConnection.Connect.Failed"))
				return;
			
			if(_reconnect_count<reconnect_count_limit)
			{
				if(debug)
					log("attempting to reconnect");
				
				e.info.code = NETCONNECTION_RECONNECT_INIT;
				e.info.level = "status";
				connect.apply(null,[_connect_string_init].concat(_connect_params_init));
				_reconnect_count++;
			} 
			else
			{
				if(debug)
					log("reconnect limit reached");
				
				e.info.code = NETCONNECTION_RECONNECT_FAILED;
				_reconnect_count = 0;
				close();
			}
			dispatchEvent(e);
		}
		
		private function handleSecurityError(e:SecurityErrorEvent):void
		{
			if(debug) 
				log(e.text);
			dispatchEvent(e);
		}
		
		private function log(msg:String):void
		{
			if(debug) 
				trace("NetConnectionSmart: "+msg);
			dispatchEvent(new MsgEvent(MSG_EVT,false,false,msg));
		}
		
	}
}

import flash.events.AsyncErrorEvent;
import flash.events.Event;
import flash.events.NetStatusEvent;
import flash.events.TimerEvent;
import flash.net.NetConnection;
import flash.utils.Timer;

class PortConnection extends NetConnection
{
	public static const STATUS_UPDATE	:String = "status_update";
	
	public var debug					:Boolean;
	public var id						:int;
	public var status					:NetStatusEvent;
	public var label					:String;
	
	private var timeoutTimer			:Timer;
	
	public function PortConnection(id:int,label:String,debug:Boolean=false)
	{
		super();
		this.debug = debug;
		this.id = id;
		this.label = label;
		addHandlers();
	}
	
	override public function connect(command:String, ...parameters):void
	{
		//start a timer here so we can watch this so if it doens't connect in time we can kill it
		if(!timeoutTimer)
		{
			timeoutTimer = new Timer(30000,1);
			timeoutTimer.addEventListener(TimerEvent.TIMER_COMPLETE,function(e:TimerEvent):void
			{
				if(debug) 
					trace("PortConnection: connection timeout");
				
				handleNetStatus(new NetStatusEvent(NetStatusEvent.NET_STATUS,false,false,{code:"NetConnection.Connect.Failed"}));
			});
		}
		timeoutTimer.start();
		
		super.connect.apply(null,[command].concat(parameters));
	}
	
	public function addHandlers():void
	{
		addEventListener(AsyncErrorEvent.ASYNC_ERROR,handleAsyncError);
		addEventListener(NetStatusEvent.NET_STATUS,handleNetStatus);
	}
	
	private function handleNetStatus(e:NetStatusEvent):void
	{
		timeoutTimer.stop();
		
		//if rejected connection came in we want to preserve that message
		if(!status || (status && status.info.code != "NetConnection.Connect.Rejected")){
			if(debug) 
				trace("PortConnection: "+e.info.code);
			status = e;
			dispatchEvent(new Event(STATUS_UPDATE));
		}
	}
	
	private function handleAsyncError(e:AsyncErrorEvent):void
	{
		if(debug)
			trace("PortConnection: "+e.toString());
	}
	
	public function removeHandlers():void
	{
		if(timeoutTimer)
			timeoutTimer.stop();
		
		timeoutTimer = null;
		
		removeEventListener(AsyncErrorEvent.ASYNC_ERROR,handleAsyncError);
		removeEventListener(NetStatusEvent.NET_STATUS,handleNetStatus);
	}
	
	public function onBWDone():void
	{
		//don't do anything
	}
	
	public function getProtocol():String
	{
		return uri.substring(0,uri.indexOf("://"));
	}
	
	public function get rejected():Boolean
	{
		try{
			return status.info.code == "NetConnection.Connect.Rejected";
		}catch(e:Error){}
		
		return false;
	}
}

class NetConnectionType
{
	public var connection		:PortConnection;
	public var port				:String;
	public var protocol			:String;
	
	public function NetConnectionType(protocol:String, port:String)
	{
		this.port = port;
		this.protocol = protocol;
	}
}