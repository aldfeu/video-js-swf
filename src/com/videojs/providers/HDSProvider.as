package com.videojs.providers{

import com.videojs.utils.Console;

import flash.display.Sprite;
import flash.display.StageAlign;
import flash.display.StageScaleMode;
import flash.media.Video;
import flash.events.Event;
import flash.utils.ByteArray;
import flash.utils.getDefinitionByName;

import flash.net.NetConnection;
import flash.net.NetGroup;
import flash.net.NetStream;

import com.akamai.osmf.AkamaiAdvancedStreamingPluginInfo;
import com.akamai.osmf.elements.AkamaiF4MElement;

import com.videojs.VideoJSModel;
import com.videojs.events.VideoPlaybackEvent;
import com.videojs.structs.ExternalErrorEventName;
import com.videojs.structs.ExternalEventName;
import com.videojs.structs.ReadyState;
import com.videojs.structs.NetworkState;

import org.osmf.containers.MediaContainer;
import org.osmf.elements.F4MElement;
import org.osmf.elements.ProxyElement;
import org.osmf.events.AudioEvent;
import org.osmf.events.BufferEvent;
import org.osmf.events.DRMEvent;
import org.osmf.events.DisplayObjectEvent;
import org.osmf.events.DynamicStreamEvent;
import org.osmf.events.LoadEvent;
import org.osmf.events.MediaElementEvent;
import org.osmf.events.MediaErrorEvent;
import org.osmf.events.MediaFactoryEvent;
import org.osmf.events.MediaPlayerStateChangeEvent;
import org.osmf.events.MediaPlayerCapabilityChangeEvent;
import org.osmf.events.PlayEvent;
import org.osmf.events.SeekEvent;
import org.osmf.events.TimeEvent;
import org.osmf.layout.HorizontalAlign;
import org.osmf.layout.LayoutMetadata;
import org.osmf.layout.LayoutTargetEvent;
import org.osmf.layout.ScaleMode;
import org.osmf.layout.VerticalAlign;
import org.osmf.media.DefaultMediaFactory;
import org.osmf.media.MediaElement;
import org.osmf.media.MediaFactory;
import org.osmf.media.MediaPlayer;
import org.osmf.media.MediaResourceBase;
import org.osmf.media.PluginInfoResource;
import org.osmf.media.MediaPlayerState;
import org.osmf.media.URLResource;
import org.osmf.metadata.Metadata;
import org.osmf.net.FMSURL;
import org.osmf.net.StreamType;
import org.osmf.net.StreamingURLResource;
import org.osmf.net.DynamicStreamingResource;
import org.osmf.net.DynamicStreamingItem;
import org.osmf.traits.DisplayObjectTrait;
import org.osmf.traits.MediaTraitType;
import org.osmf.traits.TimeTrait;
import org.osmf.traits.LoadState;
import org.osmf.traits.LoadTrait;
import org.osmf.utils.TimeUtil;


  public class HDSProvider implements IProvider {
        
        private var _networkState:Number = NetworkState.NETWORK_EMPTY;
        private var _readyState:Number = ReadyState.HAVE_NOTHING;

        // dacast specific need
        private var _levelSelected : Number;
        private var _isLive:Boolean;

        private var _model:VideoJSModel;
        private var _src:Object;
        private var _mediaFactory:MediaFactory;
        private var _mediaPlayer:MediaPlayer;	// MediaPlayer is a controller class containing no UI	
        private var _mediaContainer:MediaContainer;   // MediaContainer is the class interface between the MediaElement and the Sprite	
        private var _metadata:Object;
        private var _resource:URLResource;
        private var _mediaElement:MediaElement;
        private var _layoutMetadata:LayoutMetadata;
        private var _playRequested:Boolean;
        private var _pluginRequired:Boolean=true;

        private static const AKAMAI_PLUGIN_INFO:String = "com.akamai.osmf.AkamaiAdvancedStreamingPluginInfo";
        //private static const AKAMAI_PLUGIN_INFO:String= 'http://players.edgesuite.net/flash/plugins/osmf/advanced-streaming-plugin/v3.6/osmf2.0/AkamaiAdvancedStreamingPlugin.swf';
        private static const forceRefAkamai:AkamaiAdvancedStreamingPluginInfo = null;			

        private var _sprite:Sprite;

        public function HDSProvider() {
            _model = VideoJSModel.getInstance();
            _levelSelected = -1;
            _playRequested = false;
            _metadata = {};
            _mediaFactory = new DefaultMediaFactory();
            initPlayer();
        }

        private function initPlayer(){
            // thanks to @seniorflexdeveloper to provide a complete osmf event listening system. I just copied all events he used in his project videojs-osmf
            _mediaFactory.addEventListener(MediaFactoryEvent.MEDIA_ELEMENT_CREATE, onMediaFactoryEvent);

            _mediaPlayer = new MediaPlayer();
            _mediaPlayer.autoRewind = false;
            _mediaPlayer.loop = false;
            _mediaPlayer.currentTimeUpdateInterval = 100;

            _mediaContainer = new MediaContainer;
            _mediaContainer.clipChildren = true;
            _mediaContainer.addEventListener(LayoutTargetEvent.ADD_CHILD_AT, onLayoutTargetEvent);

            _mediaPlayer.addEventListener(AudioEvent.MUTED_CHANGE, onAudioEvent);
            _mediaPlayer.addEventListener(AudioEvent.VOLUME_CHANGE, onAudioEvent);
            _mediaPlayer.addEventListener(BufferEvent.BUFFER_TIME_CHANGE, onBufferEvent);
            _mediaPlayer.addEventListener(BufferEvent.BUFFERING_CHANGE, onBufferEvent);
            _mediaPlayer.addEventListener(MediaPlayerStateChangeEvent.MEDIA_PLAYER_STATE_CHANGE, onMediaPlayerStateChangeEvent);
            _mediaPlayer.addEventListener(MediaPlayerCapabilityChangeEvent.CAN_BUFFER_CHANGE, onMediaPlayerCapabilityChangeEvent);
            _mediaPlayer.addEventListener(MediaPlayerCapabilityChangeEvent.CAN_LOAD_CHANGE, onMediaPlayerCapabilityChangeEvent);
            _mediaPlayer.addEventListener(MediaPlayerCapabilityChangeEvent.CAN_PLAY_CHANGE, onMediaPlayerCapabilityChangeEvent);
            _mediaPlayer.addEventListener(MediaPlayerCapabilityChangeEvent.CAN_SEEK_CHANGE, onMediaPlayerCapabilityChangeEvent);
            _mediaPlayer.addEventListener(MediaPlayerCapabilityChangeEvent.HAS_AUDIO_CHANGE, onMediaPlayerCapabilityChangeEvent);
            _mediaPlayer.addEventListener(MediaPlayerCapabilityChangeEvent.HAS_DISPLAY_OBJECT_CHANGE, onMediaPlayerCapabilityChangeEvent);
            _mediaPlayer.addEventListener(MediaPlayerCapabilityChangeEvent.HAS_DRM_CHANGE, onMediaPlayerCapabilityChangeEvent);
            _mediaPlayer.addEventListener(MediaPlayerCapabilityChangeEvent.IS_DYNAMIC_STREAM_CHANGE, onMediaPlayerCapabilityChangeEvent);
            _mediaPlayer.addEventListener(MediaPlayerCapabilityChangeEvent.TEMPORAL_CHANGE, onMediaPlayerCapabilityChangeEvent);
            _mediaPlayer.addEventListener(SeekEvent.SEEKING_CHANGE, onSeekEvent);
            _mediaPlayer.addEventListener(TimeEvent.COMPLETE, onTimeEvent);
            _mediaPlayer.addEventListener(TimeEvent.CURRENT_TIME_CHANGE, onTimeEvent);
            _mediaPlayer.addEventListener(TimeEvent.DURATION_CHANGE, onTimeEvent);
            _mediaPlayer.addEventListener(LoadEvent.BYTES_LOADED_CHANGE, onLoadEvent);
            _mediaPlayer.addEventListener(LoadEvent.BYTES_TOTAL_CHANGE, onLoadEvent);
            _mediaPlayer.addEventListener(LoadEvent.LOAD_STATE_CHANGE, onLoadEvent);
            _mediaPlayer.addEventListener(DisplayObjectEvent.DISPLAY_OBJECT_CHANGE, onDisplayObjectEvent);
            _mediaPlayer.addEventListener(DisplayObjectEvent.MEDIA_SIZE_CHANGE, onDisplayObjectEvent);
            _mediaPlayer.addEventListener(PlayEvent.PLAY_STATE_CHANGE, onPlayEvent);
            _mediaPlayer.addEventListener(PlayEvent.CAN_PAUSE_CHANGE, onPlayEvent);
            _mediaPlayer.addEventListener(DynamicStreamEvent.AUTO_SWITCH_CHANGE, onDynamicStreamEvent);
            _mediaPlayer.addEventListener(DynamicStreamEvent.NUM_DYNAMIC_STREAMS_CHANGE, onDynamicStreamEvent);
            _mediaPlayer.addEventListener(DynamicStreamEvent.SWITCHING_CHANGE, onDynamicStreamEvent);
            _mediaPlayer.addEventListener(MediaErrorEvent.MEDIA_ERROR, onMediaErrorEvent);
            _mediaPlayer.addEventListener(DRMEvent.DRM_STATE_CHANGE, onDRMEvent);


            _layoutMetadata = new LayoutMetadata();
            _layoutMetadata.scaleMode = ScaleMode.LETTERBOX;
            _layoutMetadata.percentWidth = 100;
            _layoutMetadata.percentHeight = 100;
            _layoutMetadata.verticalAlign = VerticalAlign.MIDDLE;
            _layoutMetadata.horizontalAlign = HorizontalAlign.CENTER;
        }

        private function onStageResize(event:Event):void {
            if(_mediaContainer && _sprite.stage) {
                _mediaContainer.width = _sprite.stage.stageWidth;
                _mediaContainer.height = _sprite.stage.stageHeight;
            }
        }

        private function loadPlugin(source:String):void
        {
            _pluginRequired = false;
            var pluginResource:MediaResourceBase;
            if (source.substr(0, 4) == "http" || source.substr(0, 4) == "file") {
                // This is a URL, create a URLResource
                pluginResource = new URLResource(source);
            } else {
                // Assume this is a class
                var pluginInfoRef:Class = flash.utils.getDefinitionByName(source) as Class;
                pluginResource = new PluginInfoResource(new pluginInfoRef);
            }

            loadPluginFromResource(pluginResource);
        }

        private function loadPluginFromResource(pluginResource:MediaResourceBase):void
        {
            setupMediaFactoryListeners();
            _mediaFactory.loadPlugin(pluginResource);

            function setupMediaFactoryListeners(add:Boolean=true):void {
                if (add) {
                    _mediaFactory.addEventListener(MediaFactoryEvent.PLUGIN_LOAD, onPluginLoaded);
                    _mediaFactory.addEventListener(MediaFactoryEvent.PLUGIN_LOAD_ERROR, onPluginLoadFailed);
                } else {
                    _mediaFactory.removeEventListener(MediaFactoryEvent.PLUGIN_LOAD, onPluginLoaded);
                    _mediaFactory.removeEventListener(MediaFactoryEvent.PLUGIN_LOAD_ERROR, onPluginLoadFailed);
                }
            }

            function onPluginLoaded(event:MediaFactoryEvent):void {
                Console.log("Plugin LOAD SUCCESS!");
                setupMediaFactoryListeners(false);
                loadMedia();
            }

            function onPluginLoadFailed(event:MediaFactoryEvent):void {
                Console.log("Plugin LOAD FAILED!");
                setupMediaFactoryListeners(false);
            }
        }

        private function onMediaFactoryEvent(event:MediaFactoryEvent):void {
            //Console.log('onMediaFactoryEvent', event.toString(), event.type);
        }

        private function onAudioEvent(event:AudioEvent):void {
            //Console.log('onAudioEvent', event.toString());
            switch (event.type) {
              case AudioEvent.MUTED_CHANGE:
              case AudioEvent.VOLUME_CHANGE:
                _model.broadcastEventExternally(ExternalEventName.ON_VOLUME_CHANGE);
                break;
            }
        }

        private function onBufferEvent(event:BufferEvent):void {
            //Console.log('onBufferEvent', event.toString());
            switch(event.type){
                case BufferEvent.BUFFERING_CHANGE:
                    if ( !_mediaPlayer.buffering) {
                        _model.broadcastEventExternally(ExternalEventName.ON_BUFFER_FULL);
                    } else if (_mediaPlayer.playing){
                        // check end of content and send event only if it is not the end.
                        if ( _mediaPlayer.currentTime < _mediaPlayer.duration && _mediaPlayer.currentTime - _mediaPlayer.duration > 1) {
                            _model.broadcastEventExternally(ExternalEventName.ON_BUFFER_EMPTY);
                        } 
                    }
                    break;
            }
        }

        private function onMediaPlayerStateChangeEvent(event:MediaPlayerStateChangeEvent):void {
            //Console.log('onMediaPlayerStateChangeEvent', event.state, event.toString());
            switch (event.state) {
                case MediaPlayerState.PLAYING:
                    _networkState = NetworkState.NETWORK_LOADING;
                    _readyState = ReadyState.HAVE_ENOUGH_DATA;
                    _model.broadcastEventExternally(ExternalEventName.ON_CAN_PLAY);
                    _model.broadcastEventExternally(ExternalEventName.ON_SEEK_COMPLETE);
                    _model.broadcastEventExternally(ExternalEventName.ON_START);
                    _model.broadcastEventExternally(ExternalEventName.ON_RESUME);
                    break;
                case MediaPlayerState.BUFFERING:
                    _networkState = NetworkState.NETWORK_LOADING;
                    _readyState = ReadyState.HAVE_CURRENT_DATA;
                    break;
                case MediaPlayerState.PAUSED:
                    _networkState = NetworkState.NETWORK_LOADING;
                    _readyState = ReadyState.HAVE_ENOUGH_DATA;
                    _model.broadcastEventExternally(ExternalEventName.ON_CAN_PLAY);
                    break;
                case MediaPlayerState.LOADING:
                    _networkState = NetworkState.NETWORK_LOADING;
                    _readyState = ReadyState.HAVE_CURRENT_DATA;
                    _model.broadcastEventExternally(ExternalEventName.ON_START);
                    break;
                case MediaPlayerState.PLAYBACK_ERROR:
                case MediaPlayerState.UNINITIALIZED:
                    break;
            }
        }

        private function onMediaPlayerCapabilityChangeEvent(event:MediaPlayerCapabilityChangeEvent):void {
            //Console.log('onMediaPlayerCapabilityChangeEvent', event.toString());
            switch (event.type) {
                case MediaPlayerCapabilityChangeEvent.IS_DYNAMIC_STREAM_CHANGE:
                    if (event.enabled) {
                        //Console.log('onMediaPlayerCapabilityChangeEvent', "Current streaming profile index: " + _mediaPlayer.currentDynamicStreamIndex + " of " + _mediaPlayer.maxAllowedDynamicStreamIndex);
                        _mediaPlayer.addEventListener(DynamicStreamEvent.SWITCHING_CHANGE, onSwitchingChange);
                    }
            }
        }

        private function onSeekEvent(event:SeekEvent):void {
            //Console.log('onSeekEvent', event.toString());
            if(event.seeking) {
                //Console.log('onSeekEvent', ExternalEventName.ON_SEEK_START);
                _model.broadcastEventExternally(ExternalEventName.ON_SEEK_START);
            } else {
                //Console.log('onSeekEvent', ExternalEventName.ON_SEEK_COMPLETE);
                _model.broadcastEventExternally(ExternalEventName.ON_SEEK_COMPLETE);
            }
        }

        private function onTimeEvent(event:TimeEvent):void {
            //Console.log('onTimeEvent', event.toString());
            switch(event.type) {
              case TimeEvent.COMPLETE:
                    _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_STREAM_CLOSE, {}));
                    _model.broadcastEventExternally(ExternalEventName.ON_PAUSE);
                    _model.broadcastEventExternally(ExternalEventName.ON_PLAYBACK_COMPLETE);
                    seekBySeconds(0);
                    break;
              case TimeEvent.DURATION_CHANGE:
                    _model.broadcastEventExternally(ExternalEventName.ON_DURATION_CHANGE);
                    break;
              case TimeEvent.CURRENT_TIME_CHANGE:
                    break;
            }
        }

        private function onLoadEvent(event:LoadEvent):void {
            //Console.log('onLoadEvent', event.toString());
        }

        private function onPlayEvent(event:PlayEvent):void {
            //Console.log('onPlayEvent', event.toString());
            switch(event.type) {
                case PlayEvent.PLAY_STATE_CHANGE:
                    _model.broadcastEvent(new VideoPlaybackEvent(VideoPlaybackEvent.ON_STREAM_START, {info:{}}));
                    break;
                case PlayEvent.CAN_PAUSE_CHANGE:
                    if (_playRequested) {
                        _playRequested = false;
                        play();
                    }
                    break;
            }
        }

        private function onDisplayObjectEvent(event:DisplayObjectEvent):void {
            //Console.log('onDisplayObjectEvent', event.toString());
            switch(event.type){
              case DisplayObjectEvent.MEDIA_SIZE_CHANGE:
                  _metadata.width = event.newWidth;
                  _metadata.height = event.newHeight;
                  Console.log('*', 'new:', event.newWidth, event.newHeight, 'old', event.oldWidth, event.oldHeight);
                  break;
            }
        }

        private function onDynamicStreamEvent(event:DynamicStreamEvent):void {
            //Console.log('onDynamicStreamEvent', event.toString());
            switch(event.type) {
                case DynamicStreamEvent.NUM_DYNAMIC_STREAMS_CHANGE:
                    _model.broadcastEventExternally(ExternalEventName.ON_METADATA);

                    break;
                case DynamicStreamEvent.SWITCHING_CHANGE:
                    _model.broadcastEventExternally(ExternalEventName.ON_LEVEL_SWITCH);
                    break;
            }
        }

        private function onMediaErrorEvent(event:MediaErrorEvent):void {
            //Console.log('onMediaErrorEvent', event.error.name, event.error.detail, event.error.errorID, event.error.message);
            _networkState = NetworkState.NETWORK_NO_SOURCE;
            _readyState = ReadyState.HAVE_NOTHING; 
            _model.broadcastErrorEventExternally(ExternalErrorEventName.SRC_404);     
        }

        private function onDRMEvent(event:DRMEvent):void {
            //Console.log('onDRMEvent', event.drmState);
            //Console.log(event.toString());
        }

        private function onLayoutTargetEvent(event:LayoutTargetEvent):void {
            //Console.log('onLayoutTargetEvent', event.toString());
        }

        protected function onMediaElementEvent(event:MediaElementEvent):void {
            //Console.log('onMediaElementEvent', event.toString());
            switch (event.type) {
                case MediaElementEvent.METADATA_ADD:
                    //Console.log('MetaData Add', event.metadata);
                    break;

                case MediaElementEvent.METADATA_REMOVE:
                    //Console.log('MetaData Remove');
                    break;

                case MediaElementEvent.TRAIT_ADD:
                    //Console.log('Trait Add', event.type, event.traitType);
                    switch (event.traitType) {
                        case MediaTraitType.TIME:
                            if (_mediaPlayer.media.getTrait(MediaTraitType.TIME) != null) {
                                var tt:TimeTrait = _mediaPlayer.media.getTrait(MediaTraitType.TIME) as TimeTrait;
                                //Console.log("time:", tt.currentTime, TimeUtil.formatAsTimeCode(tt.duration));
                            }
                            break;

                        case MediaTraitType.DISPLAY_OBJECT:
                            if (_mediaPlayer.media.getTrait(MediaTraitType.DISPLAY_OBJECT) != null) {
                                var dt:DisplayObjectTrait = _mediaPlayer.media.getTrait(MediaTraitType.DISPLAY_OBJECT) as DisplayObjectTrait;
                                //Console.log("media size:", dt.mediaWidth, 'x', dt.mediaHeight);
                            }
                            break;

                        case MediaTraitType.DYNAMIC_STREAM:
                            break;

                        case MediaTraitType.LOAD:
                            break;

                    } 
                    break;

                case MediaElementEvent.TRAIT_REMOVE:
                    //Console.log('Trait Removed', event.type, event.traitType);
                    break;
            }
        }

        private function onSwitchingChange(event:DynamicStreamEvent):void  {
            var msg:String = "change "
            var showCurrentIndex:Boolean = false;

            if (event.switching){
                msg += "REQUESTED";
            } else {
                msg += "COMPLETE";
                showCurrentIndex = true;
            }

            //Console.log('onSwitchingChange',msg);

            if (showCurrentIndex) {
                var streamMsg:String = "Current streaming profile index: " + _mediaPlayer.currentDynamicStreamIndex + " of " + _mediaPlayer.maxAllowedDynamicStreamIndex;
                //Console.log('onSwitchingChange', streamMsg);
                streamMsg = "Current bitrate = " + _mediaPlayer.getBitrateForDynamicStreamIndex(_mediaPlayer.currentDynamicStreamIndex) + "kbps";
                //Console.log('onSwitchingChange', streamMsg);
            }
        }


        public function get loop():Boolean{
            return _mediaPlayer.loop;
        }

        public function set loop(pLoop:Boolean):void{
            _mediaPlayer.loop = pLoop;
        }

        /**
         * Should return a value that indicates the current playhead position, in seconds.
         */
        public function get time():Number {
            //Console.log('get time', _mediaPlayer.currentTime);
            return _mediaPlayer.currentTime;
        }

        /**
         * Should return a value that indicates the current asset's duration, in seconds.
         */
        public function get duration():Number  {
            if (_mediaPlayer){
                if( _isLive ) {
                    return -1;
                } else {
                    return _mediaPlayer.duration;
                }
            } else {
                return -1;
            }
        }

        /**
         * Appends the segment data in a ByteArray to the source buffer.
         * @param  bytes the ByteArray of data to append.
         */
        public function appendBuffer(bytes:ByteArray):void {
          throw "HDS Provider does not support appendBuffer";
        }

        /**
         * Should return an interger that reflects the closest parallel to
         * HTMLMediaElement's readyState property, as described here:
         * https://developer.mozilla.org/en/DOM/HTMLMediaElement
         */
        public function get readyState():int {
          return _readyState;
        }

        /**
         * Should return an interger that reflects the closest parallel to
         * HTMLMediaElement's networkState property, as described here:
         * https://developer.mozilla.org/en/DOM/HTMLMediaElement
         */
        public function get networkState():int {
          return _networkState;
        }

        /**
         * Should return the amount of media that has been buffered, in seconds, or 0 if
         * this value is unknown or unable to be determined (due to lack of duration data, etc)
         */
        public function get buffered():Number {
            return _mediaPlayer.currentTime + _mediaPlayer.bufferLength;
        }

        /**
         * Should return the number of bytes that have been loaded thus far, or 0 if
         * this value is unknown or unable to be calculated (due to streaming, bitrate switching, etc)
         */
        public function get bufferedBytesEnd():int {
            return 0;
        }

        /**
         * Should return the number of bytes that have been loaded thus far, or 0 if
         * this value is unknown or unable to be calculated (due to streaming, bitrate switching, etc)
         */
        public function get bytesLoaded():int {
            return _mediaPlayer.bytesLoaded;
        }

        /**
         * Should return the total bytes of the current asset, or 0 if this value is
         * unknown or unable to be determined (due to streaming, bitrate switching, etc)
         */
        public function get bytesTotal():int{
            return _mediaPlayer.bytesTotal;
        }

        /**
         * Should return a boolean value that indicates whether or not the current media
         * asset is playing.
         */
        public function get playing():Boolean {
            return _mediaPlayer.playing;
        }

        /**
         * Should return a boolean value that indicates whether or not the current media
         * asset is paused.
         */
        public function get paused():Boolean {
            if (_mediaPlayer.autoPlay && _mediaPlayer.currentTime == 0){
                return false;
            } 
            return !_mediaPlayer.playing;
        }

        /**
         * Should return a boolean value that indicates whether or not the current media
         * asset has ended. This value should default to false, and be reset with every seek request within
         * the same asset.
         */
        public function get ended():Boolean {
            var _isEnded:Boolean = (_mediaPlayer.duration == _mediaPlayer.currentTime)? true:false;
            return _isEnded;
        }

        /**
         * Should return a boolean value that indicates whether or not the current media
         * asset is in the process of seeking to a new time point.
         */
        public function get seeking():Boolean {
          return _mediaPlayer.seeking;
        }

        /**
         * Should return a boolean value that indicates whether or not this provider uses the NetStream class.
         */
        public function get usesNetStream():Boolean {
          return true;
        }

        /**
         * Should return an object that contains metadata properties, or an empty object if metadata doesn't exist.
         */
        public function get metadata():Object {
          return _metadata;
        }

        /**
         * Should return the most reasonable string representation of the current assets source location.
         */
        public function get srcAsString():String{
            return _resource.url;
        }

        /**
         * Should contain an object that enables the provider to play whatever media it's designed to play.
         * Compare the difference in implementation between HTTPVideoProvider and RTMPVideoProvider to see
         * one example of how this object can be used.
         */
        public function set src(pSrc:Object):void {
            _src=pSrc;
        }

        /**
         * Should return the most reasonable string representation of the current assets source location.
         */
        public function init(pSrc:Object, pAutoplay:Boolean):void {
            _mediaPlayer.autoPlay = pAutoplay;
            _src = pSrc; 
        }

        /**
         * Called when the media asset should be preloaded, but not played.
         */
        public function load():void{
            if (_resource){
                if (_resource.url == _src.f4m){
                    //Console.log('ressource already loaded');
                    return;
                }
            }

            _isLive = false;
            var url:FMSURL = new FMSURL(_src.f4m);
            if ( url.streamName.search(/@/) != -1 ) {
                _isLive = true;
            }
            _resource = new StreamingURLResource(_src.f4m ,StreamType.LIVE_OR_RECORDED);

            if (_pluginRequired) {
                loadPlugin(AKAMAI_PLUGIN_INFO);
            } else {
                loadMedia();
            }
        }
        private function loadMedia():void{
            _mediaElement = _mediaFactory.createMediaElement(_resource );

            if (_mediaElement) {
                _mediaElement.addEventListener(MediaElementEvent.TRAIT_ADD, onMediaElementEvent);
                _mediaElement.addEventListener(MediaElementEvent.TRAIT_REMOVE, onMediaElementEvent);
                _mediaElement.addEventListener(MediaElementEvent.METADATA_ADD, onMediaElementEvent);
                _mediaElement.addEventListener(MediaElementEvent.METADATA_REMOVE, onMediaElementEvent);
                _mediaElement.addEventListener(MediaErrorEvent.MEDIA_ERROR, onMediaErrorEvent);
                _mediaElement.addMetadata(LayoutMetadata.LAYOUT_NAMESPACE, _layoutMetadata);

                _mediaPlayer.autoDynamicStreamSwitch = true;
                _mediaPlayer.media = _mediaElement;
                _mediaContainer.addMediaElement( _mediaElement );
                _mediaContainer.width = _sprite.stage.stageWidth;
                _mediaContainer.height = _sprite.stage.stageHeight;
                _sprite.addChild(_mediaContainer);
                _model.broadcastEventExternally(ExternalEventName.ON_LOAD_START);
            } else {
                Console.log("ERROR CREATING MEDIA");
            }
        }

        /**
         * Called when the media asset should be played immediately.
         */
        public function play():void {
            if (_mediaPlayer.canPlay){
                _mediaPlayer.play();
                _model.broadcastEventExternally(ExternalEventName.ON_RESUME);
            } else {
                _playRequested = true;
            }
        }

        /**
         * Called when the media asset should be paused.
         */
        public function pause():void {
            if (_mediaPlayer.canPause){
                _mediaPlayer.pause();
                _model.broadcastEventExternally(ExternalEventName.ON_PAUSE);
            } else if (_mediaPlayer.playing) {
                _mediaPlayer.stop();
                _model.broadcastEventExternally(ExternalEventName.ON_PAUSE);
            }
        }

        /**
         * Called when the media asset should be resumed from a paused state.
         */
        public function resume():void {
            if (_mediaPlayer.canPlay){
                _mediaPlayer.play();
                _model.broadcastEventExternally(ExternalEventName.ON_RESUME);
            }
        }

        /**
         * Called when the media asset needs to seek to a new time point.
         */
        public function seekBySeconds(pTime:Number):void {
            if (!_mediaPlayer.seeking){
                //Console.log('can seek', _mediaPlayer.canSeek, 'seeking',_mediaPlayer.seeking, 'seek to', pTime);
                _mediaPlayer.seek(pTime);
            } else {
                //Console.log('can seek', _mediaPlayer.canSeek, 'seeking',_mediaPlayer.seeking);
            }
        }

        /**
         * Called when the media asset needs to seek to a percentage of its total duration.
         */
        public function seekByPercent(pPercent:Number):void {
            if (!_mediaPlayer.seeking){
                _mediaPlayer.seek(pPercent*_mediaPlayer.duration);
            }
        }

        /**
         * Called when the media asset needs to stop.
         */
        public function stop():void {
            _mediaPlayer.stop();
            _networkState = NetworkState.NETWORK_EMPTY;
            _readyState = ReadyState.HAVE_NOTHING;
        }

        /**
         * For providers that employ an instance of NetStream, this method is used to connect that NetStream
         * with an external Video instance without exposing it.
         */
        public function attachVideo(pVideo:Video):void {
        }

        /**
         * For providers that employ an instance of MediaElement, this method is used to connect that MediaElement
         * with an external Sprite instance without exposing it.
         */
        public function attachSprite(pSprite:Sprite):void {
            _sprite = pSprite;
            _sprite.stage.addEventListener(Event.RESIZE, onStageResize);
        }

        /**
         * Called when the provider is about to be disposed of.
         */
        public function die():void {
            if (_mediaPlayer.canPlay){
                stop();
            }
            if (_sprite){
                _sprite.removeChildren();
            }
            if(_mediaPlayer.media) {
              _mediaPlayer.media = null;
            }
        }
        

        public function endOfStream():void{
            throw "HDS Provider does not support endOfStream";
        }

        public function abort():void{
            throw "HDS Provider does not support abort";
        }        
        
        private function level2label(i:DynamicStreamingItem):String {
            //Console.log("streamItem",i);
            if (i.height){
                return i.height+"p";
            } else if ( i.bitrate ){
                return i.bitrate+"kb/s";
            } else {
                return "no name";
            }
        }

        /**
         * Should return the number of stream levels that this content has.
         */
        public function get numberOfLevels():int {
            return _mediaPlayer.numDynamicStreams;
        }

        /**
         * Should return the currently used stream level.
         */
        public function get level():int {
            if (_levelSelected >= 0)
                return _mediaPlayer.currentDynamicStreamIndex;
            else
                return _levelSelected;
        }

        public function get levels():Array{
            var _qualityLevels:Array = [];
            var autoLabel:String = "Auto";
            _qualityLevels.push({label:autoLabel,pos:-1});
            if(_mediaPlayer.canPlay && _mediaPlayer.isDynamicStream) {
                //Console.log((_mediaElement as AkamaiF4MElement).proxiedElement);
                var dsResource:DynamicStreamingResource = (_mediaElement as AkamaiF4MElement).proxiedElement.resource as DynamicStreamingResource;
                for (var i:int = 0; i < dsResource.streamItems.length; i++) {  
                    _qualityLevels.push({label:level2label(dsResource.streamItems[i]),pos:i});
                }

            }
            return _qualityLevels;
        }

        public function set level(pValue:int):void{
            if(_mediaPlayer){
                if (pValue == -1){
                    _mediaPlayer.autoDynamicStreamSwitch = true;
                    _levelSelected = pValue;
                    return;
                } 
                if (pValue != _levelSelected){
                    _levelSelected = pValue;
                    _mediaPlayer.autoDynamicStreamSwitch = false;
                    _mediaPlayer.switchDynamicStreamIndex(pValue);
                }
                return;
            }
        }

        /**
          * Should return whether auto level selection is currently enabled or not.
          */
        public function get autoLevelEnabled():Boolean {
            return _mediaPlayer.isDynamicStream;
        }
    }
}
