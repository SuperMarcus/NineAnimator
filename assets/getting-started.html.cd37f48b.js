import{r,o as c,c as l,a as e,b as t,w as a,F as d,e as i,d as n}from"./app.6eac7837.js";import{_ as h}from"./plugin-vue_export-helper.21dcd24c.js";const p={},u=e("h1",{id:"getting-started",tabindex:"-1"},[e("a",{class:"header-anchor",href:"#getting-started","aria-hidden":"true"},"#"),i(" Getting Started")],-1),m=e("h2",{id:"features",tabindex:"-1"},[e("a",{class:"header-anchor",href:"#features","aria-hidden":"true"},"#"),i(" Features")],-1),_=e("li",null,"Ads Free and no logins",-1),b=e("li",null,"Super-duper clean UIs + Dark Mode",-1),g=e("li",null,"Get notifications when new episodes come out",-1),y=e("li",null,"Apple's native video playback interface",-1),f=e("li",null,"Picture in Picture playback on iPads/iOS 14+ devices",-1),w=e("li",null,"Chromecast/Google Cast with lockscreen & control center support",-1),v=e("li",null,"Playback History & Auto Resumes",-1),k=i("Support "),S=i("Multiple Anime Websites"),A=e("li",null,"Integration with HomeKit",-1),P=e("li",null,"Discord Rich Presence integration (macOS only)",-1),N=e("li",null,"Handoff & Siri Shortcuts",-1),C=e("li",null,"Download & play episodes offline",-1),x=i("Third party anime "),M=i("listing & tracking websites"),T=i(" (view & edit)"),G=e("li",null,"Custom anime lists, e.g. favorites and to-watch list (currently retrieved from tracking websites; mutations are work-in-progress)",-1),H=e("h3",{id:"google-cast",tabindex:"-1"},[e("a",{class:"header-anchor",href:"#google-cast","aria-hidden":"true"},"#"),i(" Google Cast")],-1),O=i("NineAnimator supports playing back on both AirPlay (via Apple's native media player) and Chromecast/Google Cast devices. However, not all of the steaming sources are supported on Chromecast. Check "),D=i("Video Sources"),R=i(" for details."),j=n('<p>To use Google Cast in NineAnimator, tap on the Google Cast icon on the navigation bar. A window will pop up to prompt you to select a playback device. Once the device is connected, click &quot;Done&quot; and select an episode from the episode list. The video will starts playing automatically on the Google Cast device.</p><p>The playback control interface will appear once the playback starts. You may use the volume up/down buttons to adjust the volume.</p><p>To disconnect from a Google Cast device, tap on the Google Cast icon on the navigation bar and tap the device that is already connected.</p><h3 id="picture-in-picture-playback" tabindex="-1"><a class="header-anchor" href="#picture-in-picture-playback" aria-hidden="true">#</a> Picture in Picture Playback</h3><p>This feature is only supported on iPads, Macs, and iOS 14+ devices.</p><p>The Picture in Picture (PiP) icon will appear on the top left corner of the player once PiP is ready. You may tap on this icon to initiate PiP playback. To restore fullscreen playback, tap the restore button on the PiP window.</p><h3 id="notifications-subscription" tabindex="-1"><a class="header-anchor" href="#notifications-subscription" aria-hidden="true">#</a> Notifications &amp; Subscription</h3><p>Subscribing anime in NineAnimator is implemented with Apple&#39;s Background Application Refresh. NineAnimator will actively poll the available episodes and compares it with locally cached episodes.</p><img src="https://github.com/SuperMarcus/NineAnimator/raw/master/Misc/Media/notification_example.jpg" width="320"><p>To subscribe an anime, long press on the anime in the Recents category of your Library.</p><img src="https://github.com/SuperMarcus/NineAnimator/raw/master/Misc/Media/recents_long_press.jpeg" width="320"><p>Or simply tap on the subscribe button when you are viewing any anime.</p><img src="https://github.com/SuperMarcus/NineAnimator/raw/master/Misc/Media/subscribe_button.jpg" width="320"><h3 id="smart-home-integration" tabindex="-1"><a class="header-anchor" href="#smart-home-integration" aria-hidden="true">#</a> Smart Home Integration</h3><p>NineAnimator can be configured to run Home scenes when the playback starts and ends. The default behavior is to only run the scenes when the video is playing on external screens (e.g. Google Cast, AirPlay). However, you may change that in the <code>Settings</code> -&gt; <code>Home</code> panel.</p><ul><li>NineAnimator runs <code>Starts Playing</code> scene immediately after the video starts playing</li><li>The <code>Ends Playing</code> scene will be performed 15 seconds before video playback ends</li></ul><img src="https://github.com/SuperMarcus/NineAnimator/raw/master/Misc/Media/homekit.jpg" width="320">',17),E=i("See "),F={href:"https://github.com/SuperMarcus/NineAnimatorCommon/blob/master/Sources/NineAnimatorCommon/Utilities/Notifications.swift",target:"_blank",rel:"noopener noreferrer"},I=e("code",null,"Notifications",-1),L=i(" and "),V={href:"https://github.com/SuperMarcus/NineAnimator/blob/master/NineAnimator/Controllers/HomeController.swift",target:"_blank",rel:"noopener noreferrer"},B=e("code",null,"HomeController",-1),Y=i(" for implementation details."),q=n('<h3 id="handoff-siri-shortcuts" tabindex="-1"><a class="header-anchor" href="#handoff-siri-shortcuts" aria-hidden="true">#</a> Handoff &amp; Siri Shortcuts</h3><p>NineAnimator supports Apple&#39;s handoff and Siri Shortcuts. This enables you to seamlessly switch between devices when browsing and viewing anime.</p><img src="https://github.com/SuperMarcus/NineAnimator/raw/master/Misc/Media/continuity.jpg" width="320"><p>When you browse an anime, depending on the device you are using, the NineAnimator icon will show up on the dock (iPad) or the task switcher of your other devices. You may tap on the icon to continue browsing or watching on the new device.</p><p>To add a siri shortcut, navigate to the system settings app. Find NineAnimator under the root menu, tap <code>Siri &amp; Search</code>, then tap <code>Shortcuts</code>.</p><h3 id="download-episodes" tabindex="-1"><a class="header-anchor" href="#download-episodes" aria-hidden="true">#</a> Download Episodes</h3><p>NineAnimator can download episodes for later playback. Tap on the cloud icon in the anime browser to initiate download tasks. Downloaded episodes will appear in the Recents tab.</p><p>There are some limitations to NineAnimator&#39;s ability to download and playback videos:</p>',8),U=i("NineAnimator only supports downloading videos from a selection of "),W=i("streaming sources"),K=e("li",null,"Downloaded videos are only available to local playback. You may encounter problems playing offline episodes on AirPlay devices, and, if you are connected to a Google Cast device, NineAnimator will still attempt to fetch online resources for playback.",-1),X=n('<h2 id="device-compatibility" tabindex="-1"><a class="header-anchor" href="#device-compatibility" aria-hidden="true">#</a> Device Compatibility</h2><h3 id="ios-ipados-compatibility" tabindex="-1"><a class="header-anchor" href="#ios-ipados-compatibility" aria-hidden="true">#</a> iOS/iPadOS Compatibility</h3><p>NineAnimator is compatible with devices running iOS 13.0 or later. This includes iPhones and iPads.</p><p>The app is tested on the following devices running the latest operating systems:</p><ul><li>iPhone Xs Max</li><li>iPhone 11</li><li>iPad 9.7-inch (2018)</li><li>iPad Pro 11-inch (2018)</li></ul><h3 id="macos-compatibility" tabindex="-1"><a class="header-anchor" href="#macos-compatibility" aria-hidden="true">#</a> macOS Compatibility</h3><p>Starting from version 1.2.6 build 12, NineAnimator releases will include a macCatalyst binary build. macCatalyst allows you to run NineAnimator on compatible macOS devices.</p>',7);function z(J,Q){const o=r("RouterLink"),s=r("ExternalLinkIcon");return c(),l(d,null,[u,m,e("ul",null,[_,b,g,y,f,w,v,e("li",null,[k,t(o,{to:"/guide/supported-sources.html"},{default:a(()=>[S]),_:1})]),A,P,N,C,e("li",null,[x,t(o,{to:"/guide/third-party-lists.html"},{default:a(()=>[M]),_:1}),T]),G]),H,e("p",null,[O,t(o,{to:"/guide/supported-sources.html"},{default:a(()=>[D]),_:1}),R]),j,e("p",null,[E,e("a",F,[I,t(s)]),L,e("a",V,[B,t(s)]),Y]),q,e("ul",null,[e("li",null,[U,t(o,{to:"/guide/supported-sources.html"},{default:a(()=>[W]),_:1})]),K]),X],64)}var ee=h(p,[["render",z]]);export{ee as default};
