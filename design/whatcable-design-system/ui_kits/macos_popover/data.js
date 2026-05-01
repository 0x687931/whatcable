// Mock IOKit data for the WhatCable popover. Three fixtures
// matching the three "interesting" states: charge-only MagSafe,
// empty USB-C port, and an active SuperSpeed device.
window.WC_FIXTURES = [
  {
    label: "Steady",
    deviceCount: 0,
    ports: [
      {
        id: "p1",
        name: "Port-MagSafe 3@1",
        status: "charging",
        headline: "Charging",
        subtitle: "Power is flowing. No data connection.",
        bullets: [
          "Cable does not advertise an e-marker (basic cable)",
          "Currently negotiated: 20V @ 1.49A (30W)",
          "Plug inserted upside-down (handled automatically)",
        ],
        diagnostic: {
          kind: "ok",
          summary: "Charging well at 30W",
          detail: "Charger and cable are well-matched.",
        },
        pdos: [
          { v: "5V", a: "3A", w: "15W", active: false },
          { v: "9V", a: "3A", w: "27W", active: false },
          { v: "15V", a: "3A", w: "45W", active: false },
          { v: "20V", a: "1.49A", w: "30W", active: true },
        ],
      },
      {
        id: "p2",
        name: "Port-USB-C@4",
        status: "empty",
        headline: "Nothing connected",
        subtitle: "Plug a cable into Port-USB-C@4 to see what it can do.",
        bullets: [],
      },
      {
        id: "p3",
        name: "Port-USB-C@1",
        status: "data",
        headline: "USB device",
        subtitle: "SuperSpeed data link is active.",
        bullets: [
          "SuperSpeed USB (5 Gbps or faster)",
          "Cable does not advertise an e-marker (basic cable)",
        ],
      },
    ],
  },
  {
    label: "Bottleneck",
    deviceCount: 1,
    ports: [
      {
        id: "p1",
        name: "Port-USB-C@1",
        status: "charging",
        headline: "Charging · 96W charger",
        subtitle: "Power is flowing. No data connection.",
        bullets: [
          "Cable speed: USB 2.0 (480 Mbps)",
          "Cable rated for 3A at up to 20V (~60W)",
          "Cable made by Anker",
          "Currently negotiated: 20V @ 3A (60W)",
        ],
        diagnostic: {
          kind: "warn",
          summary: "Cable is limiting charging speed",
          detail:
            "Charger can deliver up to 96W, but this cable is only rated to carry 60W. Replace the cable to charge faster.",
        },
        pdos: [
          { v: "5V", a: "3A", w: "15W", active: false },
          { v: "9V", a: "3A", w: "27W", active: false },
          { v: "15V", a: "3A", w: "45W", active: false },
          { v: "20V", a: "3A", w: "60W", active: true },
          { v: "20V", a: "4.8A", w: "96W", active: false },
        ],
      },
      {
        id: "p2",
        name: "Port-USB-C@2",
        status: "thunderbolt",
        headline: "Thunderbolt / USB4",
        subtitle: "Supports high-speed data, video, smart cable.",
        bullets: [
          "Thunderbolt / USB4 link active",
          "Carrying DisplayPort video",
          "Cable has an e-marker chip (advertises its capabilities)",
          "Cable speed: 40 Gbps",
          "Cable rated for 5A at up to 20V (~100W)",
        ],
      },
    ],
  },
  {
    label: "Empty",
    deviceCount: 0,
    ports: [
      {
        id: "p1",
        name: "Port-USB-C@1",
        status: "empty",
        headline: "Nothing connected",
        subtitle: "Plug a cable into Port-USB-C@1 to see what it can do.",
        bullets: [],
      },
      {
        id: "p2",
        name: "Port-USB-C@2",
        status: "empty",
        headline: "Nothing connected",
        subtitle: "Plug a cable into Port-USB-C@2 to see what it can do.",
        bullets: [],
      },
    ],
  },
];

window.WC_UPDATE = {
  version: "0.2.1",
  current: "0.2.0",
};
