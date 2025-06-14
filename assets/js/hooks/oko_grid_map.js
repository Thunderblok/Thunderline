// OKO GridWorld Google Maps Integration Hook
// Handles real-time PAC tracking on Google Maps with 3D grid overlay

import { Loader } from "@googlemaps/js-api-loader";

export default {
  mounted() {
    const hook = this;
    const element = hook.el;
    
    // Initialize hook data
    hook.map = null;
    hook.pacs = [];
    hook.markers = new Map();
    hook.gridOverlays = [];
    hook.infoWindow = null;
    
    // Get initial data from DOM attributes
    const region = element.dataset.region;
    const center = JSON.parse(element.dataset.center);
    const zoom = parseInt(element.dataset.zoom);
    
    // Google Maps API configuration
    const loader = new Loader({
      apiKey: this.getApiKey(), // You'll need to set this
      version: "weekly",
      libraries: ["maps", "geometry", "visualization"]
    });
    
    // Load Google Maps
    loader
      .importLibrary('maps')
      .then(({ Map, InfoWindow, Marker, Polyline, Polygon }) => {
        // Initialize map
        hook.map = new Map(element, {
          center: center,
          zoom: zoom,
          mapTypeId: 'satellite', // Satellite view for better grid visualization
          styles: this.getMapStyles(),
          zoomControl: true,
          mapTypeControl: true,
          scaleControl: true,
          streetViewControl: false,
          rotateControl: true,
          fullscreenControl: true
        });
        
        // Initialize info window
        hook.infoWindow = new InfoWindow();
        
        // Set up map event listeners
        hook.map.addListener('click', (event) => {
          const lat = event.latLng.lat();
          const lng = event.latLng.lng();
          hook.pushEvent("place_pac", { lat: lat, lng: lng });
        });
        
        // Initialize grid overlay
        hook.initializeGridOverlay();
        
        // Load any existing PACs
        hook.updatePACs();
        
        console.log("🌍 OKO GridWorld Map initialized for region:", region);
      })
      .catch(error => {
        console.error("❌ Failed to load Google Maps:", error);
      });
    
    // Handle LiveView events
    hook.handleEvent("update_pacs", (payload) => {
      console.log("🔄 Updating PACs:", payload);
      hook.pacs = payload.pacs || [];
      if (hook.map) {
        hook.updatePACs();
      }
    });
    
    // Handle grid control changes
    this.setupGridControls();
  },
  
  updated() {
    const hook = this;
    if (hook.map) {
      hook.updatePACs();
    }
  },
  
  // Get API key (you'll need to configure this)
  getApiKey() {
    // In production, get this from a secure configuration
    return window.GOOGLE_MAPS_API_KEY || 'YOUR_API_KEY_HERE';
  },
  
  // Custom map styling for OKO GridWorld
  getMapStyles() {
    return [
      {
        "featureType": "all",
        "stylers": [
          { "saturation": -20 },
          { "lightness": -10 }
        ]
      },
      {
        "featureType": "administrative",
        "elementType": "geometry",
        "stylers": [
          { "color": "#1e293b" },
          { "weight": 1 }
        ]
      },
      {
        "featureType": "water",
        "stylers": [
          { "color": "#0f172a" }
        ]
      }
    ];
  },
  
  // Initialize 3D grid overlay on the map
  initializeGridOverlay() {
    const hook = this;
    if (!hook.map) return;
    
    const bounds = hook.map.getBounds();
    if (!bounds) return;
    
    // Create grid lines based on map bounds
    const ne = bounds.getNorthEast();
    const sw = bounds.getSouthWest();
    
    const latStep = (ne.lat() - sw.lat()) / 20; // 20 grid lines
    const lngStep = (ne.lng() - sw.lng()) / 20;
    
    // Clear existing grid
    hook.gridOverlays.forEach(overlay => overlay.setMap(null));
    hook.gridOverlays = [];
    
    // Draw latitude lines
    for (let lat = sw.lat(); lat <= ne.lat(); lat += latStep) {
      const line = new google.maps.Polyline({
        path: [
          { lat: lat, lng: sw.lng() },
          { lat: lat, lng: ne.lng() }
        ],
        geodesic: true,
        strokeColor: '#3b82f6',
        strokeOpacity: 0.3,
        strokeWeight: 1,
        map: hook.map
      });
      hook.gridOverlays.push(line);
    }
    
    // Draw longitude lines  
    for (let lng = sw.lng(); lng <= ne.lng(); lng += lngStep) {
      const line = new google.maps.Polyline({
        path: [
          { lat: sw.lat(), lng: lng },
          { lat: ne.lat(), lng: lng }
        ],
        geodesic: true,
        strokeColor: '#3b82f6',
        strokeOpacity: 0.3,
        strokeWeight: 1,
        map: hook.map
      });
      hook.gridOverlays.push(line);
    }
  },
  
  // Update PAC markers on the map
  updatePACs() {
    const hook = this;
    if (!hook.map) return;
    
    // Clear existing markers
    hook.markers.forEach(marker => marker.setMap(null));
    hook.markers.clear();
    
    // Add markers for current PACs
    hook.pacs.forEach(pac => {
      const marker = new google.maps.Marker({
        position: { lat: pac.lat, lng: pac.lng },
        map: hook.map,
        title: `PAC ${pac.pac_id.slice(0, 8)}`,
        icon: {
          path: google.maps.SymbolPath.CIRCLE,
          scale: 12,
          fillColor: this.getPACColor(pac),
          fillOpacity: 0.8,
          strokeColor: '#ffffff',
          strokeWeight: 2
        },
        animation: google.maps.Animation.DROP
      });
      
      // Add PAC info window
      marker.addListener('click', () => {
        const content = `
          <div style="color: white; background: #1e293b; padding: 10px; border-radius: 8px;">
            <h3 style="margin: 0 0 10px 0; color: #60a5fa;">⚡ PAC ${pac.pac_id.slice(0, 8)}</h3>
            <p style="margin: 5px 0;"><strong>Position:</strong> ${pac.lat.toFixed(6)}, ${pac.lng.toFixed(6)}</p>
            <p style="margin: 5px 0;"><strong>Grid:</strong> (${pac.x.toFixed(2)}, ${pac.y.toFixed(2)}, ${pac.z.toFixed(2)})</p>
            <p style="margin: 5px 0;"><strong>Region:</strong> ${pac.region_id}</p>
            <p style="margin: 5px 0;"><strong>Tick:</strong> ${pac.tick_id}</p>
            <p style="margin: 5px 0;"><strong>Heading:</strong> ${pac.heading}°</p>
            <p style="margin: 5px 0;"><strong>Velocity:</strong> ${pac.velocity} m/s</p>
            <button onclick="removePAC('${pac.pac_id}')" 
                    style="background: #dc2626; color: white; border: none; padding: 5px 10px; border-radius: 4px; margin-top: 10px; cursor: pointer;">
              Remove PAC
            </button>
          </div>
        `;
        
        hook.infoWindow.setContent(content);
        hook.infoWindow.open(hook.map, marker);
      });
      
      // Add drag functionality for PAC movement
      marker.setDraggable(true);
      marker.addListener('dragend', (event) => {
        const lat = event.latLng.lat();
        const lng = event.latLng.lng();
        hook.pushEvent("move_pac", { 
          pac_id: pac.pac_id, 
          lat: lat, 
          lng: lng 
        });
      });
      
      hook.markers.set(pac.pac_id, marker);
    });
  },
  
  // Get color based on PAC properties
  getPACColor(pac) {
    // Color based on region or other properties
    const colors = {
      'sector_alpha': '#3b82f6',   // Blue
      'sector_beta': '#10b981',    // Green  
      'sector_gamma': '#f59e0b',   // Amber
      'global_grid': '#8b5cf6'     // Purple
    };
    
    return colors[pac.region_id] || '#6b7280'; // Default gray
  },
  
  // Setup grid control event listeners
  setupGridControls() {
    const hook = this;
    
    document.getElementById('show-grid')?.addEventListener('change', (e) => {
      const show = e.target.checked;
      hook.gridOverlays.forEach(overlay => {
        overlay.setVisible(show);
      });
    });
    
    document.getElementById('show-regions')?.addEventListener('change', (e) => {
      // Toggle region boundaries (implement as needed)
    });
    
    document.getElementById('show-coordinates')?.addEventListener('change', (e) => {
      // Toggle coordinate display (implement as needed)
    });
    
    document.getElementById('show-trails')?.addEventListener('change', (e) => {
      // Toggle PAC movement trails (implement as needed)
    });
  }
};

// Global function for removing PACs (called from info window)
window.removePAC = function(pacId) {
  const event = new CustomEvent('phx:remove_pac', {
    detail: { pac_id: pacId }
  });
  document.dispatchEvent(event);
};
