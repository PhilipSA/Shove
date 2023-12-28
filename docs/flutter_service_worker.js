'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "2b04891dc72388bc238b46601d5af374",
"assets/AssetManifest.bin.json": "f29c53b7ea6ae710efb3511d73178dad",
"assets/AssetManifest.json": "fd4cda30c3a69ad72ab989eef35c65cf",
"assets/assets/icn_archive.svg": "056e2ddd0273f9d73150e44a315d7fd2",
"assets/assets/icn_arrow_right.svg": "f84b58f051f6e4d58cd1adb7a0b15723",
"assets/assets/icn_bell_notification.svg": "1a1e15bf0d7c3e3030d1cdd3dfebdbbd",
"assets/assets/icn_bin.svg": "88b4610aa5242b6089ec581c7f50f6d2",
"assets/assets/icn_calendar.svg": "e284f77eb8b29bced668a2d8589c1436",
"assets/assets/icn_calendar_x.svg": "52436795d9b27c782ebceac022661f86",
"assets/assets/icn_camera.svg": "7abfd09bf3a3169ba785616bc17af413",
"assets/assets/icn_check.svg": "908d224bd80cd4531cac83d8cf37c660",
"assets/assets/icn_chevron_left.svg": "c306a4eaa47878a84352f3424b841f3a",
"assets/assets/icn_clock.svg": "2544643d9b3a01a5a69fa4bb7e05f3c6",
"assets/assets/icn_download.svg": "46ebb0cda5ffe7af72976bee155e5415",
"assets/assets/icn_email.svg": "61e57a93e4c7523f9180fd19ad653a25",
"assets/assets/icn_file_error.svg": "8f6fa94b7a23471d93a2eb0af825e555",
"assets/assets/icn_file_other_formats.svg": "6ba6d97ce43ab112a973a6eee712ea20",
"assets/assets/icn_file_pdf.svg": "48f7d9d7627125652ea9e4b436c085f8",
"assets/assets/icn_flag_de.svg": "b58fc92c160707f3c515d65d501b7c78",
"assets/assets/icn_flag_dk.svg": "2e7647377e55b6d342c07c12ab455a97",
"assets/assets/icn_flag_fi.svg": "f46e26e94bccdccccca131f3bc69288b",
"assets/assets/icn_flag_nl.svg": "727fcdc4a4f0b6e424c9404018c4df61",
"assets/assets/icn_flag_no.svg": "c753369388f586b92baee4618259d7f5",
"assets/assets/icn_flag_se.svg": "8767aced8fc30366b6d114033e43ae68",
"assets/assets/icn_flag_uk.svg": "b0d9f6c84ab47417a90242ef0a26bdba",
"assets/assets/icn_group.svg": "df0afa65859cd1f1e4070b93ef9fe9b2",
"assets/assets/icn_hourglass.svg": "ebb61c8cf74007f60c91eb0b4aa87d95",
"assets/assets/icn_house.svg": "757be03a22007098ce7c62d391889c0d",
"assets/assets/icn_house_filled.svg": "fc5140038b954592df4dfb108008291e",
"assets/assets/icn_illustration_cases.svg": "518fd72b8067f426fa4fad073fb2d1e2",
"assets/assets/icn_info_circle.svg": "04f3bf78cf70d6c9f422fda287016d1c",
"assets/assets/icn_login.svg": "9a6210fb9c12e1951e74790dc6e76064",
"assets/assets/icn_logout.svg": "aa69be2aff4cbf9f460ec9ee96f68ab1",
"assets/assets/icn_notes_board_pencil.svg": "321f45b4f2256a897eafecfa1657837f",
"assets/assets/icn_paperplane_filled.svg": "c623fcfc0d2aa3c517afd2bfae22a30a",
"assets/assets/icn_paper_clip.svg": "bb9fd5c14aec49de71f654be5d818dd9",
"assets/assets/icn_pin_mark.svg": "05673847bb0b376508f14171a9135319",
"assets/assets/icn_smartphone_sms.svg": "9c539fb5926744b0d83e6bfcdee0a972",
"assets/assets/icn_speech_bubble_lines.svg": "4fada32ebf0b6ad6cfa3cd1d6951ddf1",
"assets/assets/icn_user.svg": "66183fd773f325e26d360dbe5b7d9806",
"assets/assets/icn_video.svg": "901362c353566518eca1b192f389fc55",
"assets/assets/icn_video_crossed.svg": "d1c3afa357536fc075ad5eaddddd02bf",
"assets/assets/icn_wallet.svg": "3f37dca5a5fd489eca272741266cf2ba",
"assets/assets/icn_warning.svg": "1aa77d3d9300d972b244195116c245b3",
"assets/assets/icn_warning_circle.svg": "b2256b626cb32bfb9e3b599a8385f172",
"assets/assets/icn_x.svg": "6298e390a2395353153e3af4d439dac2",
"assets/assets/sounds/Bonk_1.mp3": "ed6e38a7a8008ee99301e37abe9bcafa",
"assets/assets/sounds/Chains_1.mp3": "453b86b926416c8476775688b7abdb2d",
"assets/assets/sounds/Jump.mp3": "059761a8845c2145683032d291a6d20b",
"assets/assets/sounds/Jump_2.mp3": "6fa10fe4f4fbc04ff4f5c6baed7358bd",
"assets/assets/sounds/music/Action_2.mp3": "a4a3e953c2266fbbad5b672d2c9e472b",
"assets/assets/sounds/music/GameMusic.mp3": "b9f3000e36e2df501c6504cd150def2c",
"assets/assets/sounds/ThrowSound.mp3": "58f14b3feca259667f8644db7f1e1060",
"assets/assets/sounds/Yodascream.mp3": "8d98275c2383dfda20c499e6a8e3ccb0",
"assets/assets/textures/ankare.svg": "90690d6ae0612c2f0c9e3537e28a872b",
"assets/assets/textures/hoppare.svg": "7cfb6b4c3ac18e408ee4ec687be99985",
"assets/assets/textures/inv_ankare.svg": "366f7530f15177b1a6731a7ae3f62ca7",
"assets/assets/textures/inv_hoppare.svg": "345f7379ee7086a514bd0c5ec75fb430",
"assets/assets/textures/inv_kastare.svg": "ea93e3da1d307527976ca091ee25e74d",
"assets/assets/textures/inv_knuffare.svg": "e233ef8a7b4b37a632ef3d542ec86003",
"assets/assets/textures/kastare.svg": "9ecd17a188f8395ee57a7e8ee5f0f0e5",
"assets/assets/textures/knuffare.svg": "cf415c4a3aa1ee083d61d6da2efb1396",
"assets/assets/textures/shover.png": "183124e71a18ef0d7d18363136785388",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "5ea9b5909247c4e7e9f5adda2f8a1535",
"assets/NOTICES": "023c9a7f113554086c62458776995d00",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "89ed8f4e49bcdfc0b5bfc9b24591e347",
"assets/shaders/ink_sparkle.frag": "4096b5150bac93c41cbc9b45276bd90f",
"canvaskit/canvaskit.js": "eb8797020acdbdf96a12fb0405582c1b",
"canvaskit/canvaskit.wasm": "73584c1a3367e3eaf757647a8f5c5989",
"canvaskit/chromium/canvaskit.js": "0ae8bbcc58155679458a0f7a00f66873",
"canvaskit/chromium/canvaskit.wasm": "143af6ff368f9cd21c863bfa4274c406",
"canvaskit/skwasm.js": "87063acf45c5e1ab9565dcf06b0c18b8",
"canvaskit/skwasm.wasm": "2fc47c0a0c3c7af8542b601634fe9674",
"canvaskit/skwasm.worker.js": "bfb704a6c714a75da9ef320991e88b03",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "59a12ab9d00ae8f8096fffc417b6e84f",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "b29bee62330a81b3f54394b2f9b95e05",
"/": "b29bee62330a81b3f54394b2f9b95e05",
"main.dart.js": "6f313af92ed66cea9c9d937fe8b23ae8",
"manifest.json": "868a132b31d419c6eb0a90d65c7f9244",
"version.json": "f8ece199c660f0e0b0e6f9972408f27a"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"assets/AssetManifest.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
