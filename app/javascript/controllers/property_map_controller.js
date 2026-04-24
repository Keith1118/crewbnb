import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    lat: Number,
    lng: Number,
    title: String,
    apiKey: String
  }

  static targets = ["map", "streetView", "streetViewFallback", "nearbyPlaces"]

  connect() {
    if (!this.latValue || !this.lngValue) {
      this._showLocationUnavailable()
      return
    }

    if (!this.apiKeyValue) {
      this._showLocationUnavailable()
      return
    }

    this._loadGoogleMapsAPI().then(() => {
      this._initMap()
      this._initStreetView()
      this._initNearbyPlaces()
    }).catch(() => {
      this._showLocationUnavailable()
    })
  }

  // ---------- Google Maps API Loader ----------

  _loadGoogleMapsAPI() {
    // If already loaded
    if (window.google && window.google.maps) {
      return Promise.resolve()
    }

    // If already loading, wait for it
    if (window._googleMapsLoadPromise) {
      return window._googleMapsLoadPromise
    }

    window._googleMapsLoadPromise = new Promise((resolve, reject) => {
      const script = document.createElement("script")
      script.src = `https://maps.googleapis.com/maps/api/js?key=${this.apiKeyValue}&libraries=places,streetview&v=weekly`
      script.async = true
      script.defer = true
      script.onload = resolve
      script.onerror = reject
      document.head.appendChild(script)
    })

    return window._googleMapsLoadPromise
  }

  // ---------- Map ----------

  _initMap() {
    const position = { lat: this.latValue, lng: this.lngValue }

    this.map = new google.maps.Map(this.mapTarget, {
      center: position,
      zoom: 15,
      mapTypeControl: false,
      fullscreenControl: true,
      streetViewControl: true,
      zoomControl: true,
      styles: [
        {
          featureType: "poi",
          elementType: "labels",
          stylers: [{ visibility: "off" }]
        }
      ]
    })

    new google.maps.Marker({
      position: position,
      map: this.map,
      title: this.titleValue || "Property location"
    })
  }

  // ---------- Street View ----------

  _initStreetView() {
    const position = { lat: this.latValue, lng: this.lngValue }
    const sv = new google.maps.StreetViewService()

    sv.getPanorama({ location: position, radius: 100 }, (data, status) => {
      if (status === google.maps.StreetViewStatus.OK) {
        const heading = google.maps.geometry
          ? google.maps.geometry.spherical.computeHeading(data.location.latLng, new google.maps.LatLng(position))
          : 0

        new google.maps.StreetViewPanorama(this.streetViewTarget, {
          position: data.location.latLng,
          pov: { heading: heading || 0, pitch: 0 },
          zoom: 1,
          addressControl: false,
          fullscreenControl: true,
          motionTracking: false
        })
        this.streetViewTarget.classList.remove("hidden")
        if (this.hasStreetViewFallbackTarget) {
          this.streetViewFallbackTarget.classList.add("hidden")
        }
      } else {
        // Street View not available
        this.streetViewTarget.classList.add("hidden")
        if (this.hasStreetViewFallbackTarget) {
          this.streetViewFallbackTarget.classList.remove("hidden")
        }
      }
    })
  }

  // ---------- Nearby Places ----------

  _initNearbyPlaces() {
    const service = new google.maps.places.PlacesService(this.map)
    const position = new google.maps.LatLng(this.latValue, this.lngValue)

    this.categories = [
      { key: "supermarket", label: "Supermarkets & Grocery", icon: "local_grocery_store", types: ["supermarket"] },
      { key: "restaurant", label: "Restaurants & Cafes", icon: "restaurant", types: ["restaurant"] },
      { key: "transit", label: "Public Transport", icon: "directions_bus", types: ["transit_station"] },
      { key: "pharmacy", label: "Pharmacies", icon: "local_pharmacy", types: ["pharmacy"] },
      { key: "convenience", label: "Convenience Stores", icon: "store", types: ["convenience_store"] }
    ]

    this.placesResults = {}
    let completed = 0
    const total = this.categories.length

    this.categories.forEach((category) => {
      const request = {
        location: position,
        rankBy: google.maps.places.RankBy.DISTANCE,
        type: category.types[0]
      }

      service.nearbySearch(request, (results, status) => {
        completed++

        if (status === google.maps.places.PlacesServiceStatus.OK && results.length > 0) {
          const processed = results.slice(0, 5).map((place) => {
            const dist = this._haversineDistance(
              this.latValue, this.lngValue,
              place.geometry.location.lat(), place.geometry.location.lng()
            )
            return {
              name: place.name,
              distance: dist,
              walkingTime: Math.ceil((dist / 5) * 60)
            }
          })
          processed.sort((a, b) => a.distance - b.distance)
          this.placesResults[category.key] = processed
        }

        if (completed === total) {
          this._renderNearbyPlaces()
        }
      })
    })
  }

  _renderNearbyPlaces() {
    const container = this.nearbyPlacesTarget
    const hasAnyResults = Object.keys(this.placesResults).length > 0

    if (!hasAnyResults) {
      container.innerHTML = `
        <div class="text-center py-10">
          <span class="material-symbols-outlined text-4xl text-outline-variant/40">location_off</span>
          <p class="text-on-surface-variant mt-3 text-sm">No nearby places data available for this location.</p>
        </div>
      `
      return
    }

    let html = '<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">'

    this.categories.forEach((category) => {
      const places = this.placesResults[category.key]
      if (!places || places.length === 0) return

      html += `
        <div>
          <div class="flex items-center gap-2 mb-3">
            <span class="material-symbols-outlined text-primary-container text-xl">${category.icon}</span>
            <h4 class="font-headline text-sm font-bold text-on-surface">${category.label}</h4>
          </div>
          <div class="space-y-2">
      `

      places.forEach((place) => {
        html += `
          <div class="flex items-center justify-between p-3 rounded-xl bg-surface-container border border-outline-variant/10">
            <span class="text-sm text-on-surface font-medium truncate mr-3">${this._escapeHtml(place.name)}</span>
            <div class="flex items-center gap-3 shrink-0">
              <span class="text-xs text-on-surface-variant">${place.distance.toFixed(1)} km</span>
              <span class="flex items-center gap-1 text-xs text-on-surface-variant">
                <span class="material-symbols-outlined text-sm">directions_walk</span>
                ${place.walkingTime} min
              </span>
            </div>
          </div>
        `
      })

      html += "</div></div>"
    })

    html += "</div>"
    container.innerHTML = html
  }

  // ---------- Helpers ----------

  _haversineDistance(lat1, lon1, lat2, lon2) {
    const R = 6371 // km
    const dLat = this._toRad(lat2 - lat1)
    const dLon = this._toRad(lon2 - lon1)
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
              Math.cos(this._toRad(lat1)) * Math.cos(this._toRad(lat2)) *
              Math.sin(dLon / 2) * Math.sin(dLon / 2)
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    return R * c
  }

  _toRad(deg) {
    return deg * (Math.PI / 180)
  }

  _escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  _showLocationUnavailable() {
    if (this.hasMapTarget) {
      this.mapTarget.innerHTML = `
        <div class="flex items-center justify-center h-full">
          <div class="text-center">
            <span class="material-symbols-outlined text-4xl text-outline-variant/40">location_off</span>
            <p class="text-on-surface-variant mt-3 text-sm">Location data not available for this property.</p>
          </div>
        </div>
      `
    }
  }
}
