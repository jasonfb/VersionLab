export const PLATFORMS = {
  "Facebook (Meta)": [
    { name: "Feed Image",  width: 1080, height: 1080 },
    { name: "Story",       width: 1080, height: 1920 },
    { name: "Landscape",   width: 1200, height: 628  },
  ],
  "Google Display": [
    { name: "Leaderboard",      width: 728,  height: 90  },
    { name: "Medium Rectangle", width: 300,  height: 250 },
    { name: "Large Rectangle",  width: 336,  height: 280 },
    { name: "Half Page",        width: 300,  height: 600 },
    { name: "Wide Skyscraper",  width: 160,  height: 600 },
  ],
  "Instagram": [
    { name: "Feed Square",   width: 1080, height: 1080 },
    { name: "Feed Portrait", width: 1080, height: 1350 },
    { name: "Story",         width: 1080, height: 1920 },
  ],
  "LinkedIn": [
    { name: "Single Image", width: 1200, height: 627 },
    { name: "Square",       width: 1080, height: 1080 },
  ],
  "Pinterest": [
    { name: "Standard Pin", width: 1000, height: 1500 },
    { name: "Square Pin",   width: 1000, height: 1000 },
  ],
  "Reddit":   [{ name: "Feed Image",  width: 1200, height: 628 }],
  "Snapchat": [{ name: "Full Screen", width: 1080, height: 1920 }],
  "Threads":  [{ name: "Feed Image",  width: 1080, height: 1080 }],
  "TikTok":   [{ name: "In-Feed",     width: 1080, height: 1920 }],
  "X": [
    { name: "Single Image", width: 1200, height: 675 },
    { name: "Square",       width: 1080, height: 1080 },
  ],
  "YouTube": [
    { name: "Display Banner", width: 300, height: 250 },
    { name: "Overlay",        width: 480, height: 70  },
  ],
}

export const PLATFORM_NAMES = Object.keys(PLATFORMS)

// selectedPlatforms is { [platformName]: sizeName[] }
export function deduplicatedSizes(selectedPlatforms) {
  const byDims = {}

  Object.entries(selectedPlatforms).forEach(([platform, sizeNames]) => {
    const allSizes = PLATFORMS[platform] || []
    const filtered = allSizes.filter((s) => sizeNames.includes(s.name))
    filtered.forEach((size) => {
      const key = `${size.width}x${size.height}`
      if (!byDims[key]) {
        byDims[key] = { width: size.width, height: size.height, labels: [] }
      }
      byDims[key].labels.push({ platform, sizeName: size.name })
    })
  })

  return Object.values(byDims)
}
