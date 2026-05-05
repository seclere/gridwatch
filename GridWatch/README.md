# GridWatch — iOS App

Real-time WESM energy pricing dashboard with smart socket automation.

## Project Structure

```
GridWatch/
├── App/
│   ├── GridWatchApp.swift       # @main entry, injects environment objects
│   └── ContentView.swift        # Horizontal TabView (Sockets | Dashboard | Schedule)
│
├── Models/
│   ├── PriceModel.swift         # WESMPrice, ScheduleEntry, PeakStatus
│   └── SmartSocket.swift        # SmartSocket, Appliance models
│
├── ViewModels/
│   ├── PriceViewModel.swift     # Polls API, classifies peak, exposes tally helpers
│   ├── SocketStore.swift        # CRUD for sockets, applies peak policy
│   └── ScheduleStore.swift      # Holds 24-entry table, CSV import
│
├── Views/
│   ├── Dashboard/
│   │   └── DashboardView.swift  # Center page — live price, tally, socket summary
│   ├── Sockets/
│   │   └── SocketsView.swift    # Left page — socket list, detail/edit, add socket
│   └── Schedule/
│       └── ScheduleView.swift   # Right page — bar chart, threshold slider, hour table
│
└── Services/
    ├── WESMService.swift         # Fetches from your Replit API endpoint
    └── SocketControlService.swift # Boilerplate stub — replace with real SDK
```

## Navigation

The app uses a **horizontal paging TabView**:
- Swipe **right → left** to go from Dashboard to Schedule  
- Swipe **left → right** to go from Dashboard to Sockets  
- App always opens on the Dashboard (center page)

## Setup in Xcode

1. Create a new **SwiftUI App** project in Xcode (iOS 17+, Swift 5.9+).
2. Copy all `.swift` files from this folder into the project, preserving the group structure.
3. Build & run — no third-party dependencies needed.

## API

- **Endpoint**: `https://fca56e6b-9cee-4c14-b6da-8b099f224303-00-1hvq6fpq2mbky.spock.replit.dev/api/luzon-price`
- **Response**: Plain integer string, e.g. `4296`
- **Unit**: ₱ / MWh → divide by 1000 to get ₱/kWh
- **Poll interval**: 5 minutes (configurable in `PriceViewModel.pollInterval`)

Add `NSAppTransportSecurity` to `Info.plist` if your Replit URL is HTTP (it's HTTPS so you're fine by default).

## Google Sheets → Schedule

1. In your Google Sheet, set up three columns:

   | hour | priceMWh | peakOverride |
   |------|----------|--------------|
   | 0    | 1800     |              |
   | 1    | 1750     |              |
   | 6    | 4800     | onPeak       |
   | ...  | ...      | ...          |

   - `hour`: integer 0–23
   - `priceMWh`: WESM price in ₱/MWh (integer); leave blank for unknown hours
   - `peakOverride`: `onPeak` or `offPeak` to force-classify; leave blank to use the threshold slider

2. **File → Download → Comma-separated values (.csv)**
3. In the app, go to **Schedule → Import CSV** (top-right icon) and paste the CSV.

## Smart Socket Integration (TODO)

Open `Services/SocketControlService.swift` and replace the boilerplate `setPower()` body with your real SDK call. Options:

| Platform       | How to integrate                                      |
|----------------|-------------------------------------------------------|
| Home Assistant | REST API POST `/api/services/switch/turn_on`          |
| Tuya / Smart Life | Add `pod 'ThingSmartDeviceKit'` and call `publishDps` |
| TP-Link Kasa   | UDP commands or `python-kasa` bridge via your API     |
| Matter/HomeKit | `HMCharacteristic.writeValue(true, completionHandler:)` |

## Peak Classification Logic

A price reading is **on-peak** if `priceMWh / 1000 >= peakThresholdKwh`.  
The threshold defaults to **₱5.00/kWh** and is adjustable via the Schedule page slider.  
A `peakOverride` in the schedule table always wins over the threshold.

A socket is **auto-managed** (turns off during on-peak) if it contains at least one non-essential appliance.  
Mark appliances as Essential in the socket detail view to exempt them from auto-control.
