# Earth Globe Asset Attribution

## Earth surface
- Asset: `earth_blue_marble.jpg` (4096×2048 equirectangular)
- Source: NASA Earth Observatory, Blue Marble: Next Generation — July base map.
- Original global source: https://assets.science.nasa.gov/content/dam/science/esd/eo/images/bmng/bmng-base/july/world.200407.3x5400x2700.jpg
- NASA collection: https://science.nasa.gov/earth/earth-observatory/blue-marble-next-generation/base-map/
- Credit: Reto Stöckli, NASA Earth Observatory, Terra/MODIS. The 4096×2048 delivery is a resampled derivative of NASA's 5400×2700 global image.
- This surface map has no cloud layer, city labels, or night-light overlay.

## Clouds
- Asset: `earth_clouds.jpg`
- Source: NASA Visible Earth, Blue Marble: Clouds.
- Original source record: https://visibleearth.nasa.gov/images/57747/blue-marble-clouds/77558l
- Credit: NASA Goddard Space Flight Center; Reto Stöckli (land surface, shallow water, clouds); enhancements by Robert Simmon.
- Rendered as a separate transparent shell above the Earth surface.

NASA imagery is credited as a courtesy; no NASA endorsement is implied. NASA media guidance: https://www.nasa.gov/nasa-brand-center/images-and-media/


## Country geography
- Asset: `natural_earth_countries.json`
- Source: Natural Earth, 1:110m Admin 0 Countries.
- Source dataset: https://www.naturalearthdata.com/downloads/110m-cultural-vectors/110m-admin-0-countries/
- License: Natural Earth vector and raster map data are public domain.
- Scope: country/territory outlines and label coordinates for the global overview. This 1:110m dataset is intentionally a low-detail overview layer; higher-resolution 1:50m and 1:10m layers are not yet included.


## Cartographic presentation
- Boundary and label presentation is an original implementation inspired by the restrained visual hierarchy used by Google Earth.
- Google Earth datasets, source code, map tiles, logos, and proprietary visual assets are not included or copied.
- Country geometry remains sourced from Natural Earth. The current bundled layer is Admin 0 at 1:110m scale and is suitable only for global overview use.
- The current style pass uses shaded cool-grey boundary lines, removes duplicate shared polygon edges where coordinates match, keeps boundaries close to the globe surface, and reduces country-label prominence.
- Higher-resolution Admin 0, Admin 1, and Admin 2 geography is a separate future data integration; it is not represented as available in this build.


## Progressive country and state geography
- Country overview remains available from the existing Natural Earth 1:110m Admin-0 dataset.
- Higher-detail country tiers are generated from Natural Earth 1:50m and 1:10m Admin-0 Countries, version 5.1.1.
- First-level internal administrative divisions are generated from Natural Earth 1:10m Admin-1 States and Provinces, version 5.1.1 (4,596 features). No Admin-2 counties, cities, or deeper location layers are included.
- Admin-1 data is partitioned into continent-sized gzip-compressed JSON chunks. The globe loads only the chunk nearest the current camera view and swaps chunks when the user rotates to another continent, avoiding a full-world state mesh on mobile.
- Country tiers and state chunks are loaded only after their corresponding zoom thresholds are reached.
- Natural Earth data is public domain. Source catalogue: https://www.naturalearthdata.com/downloads/10m-cultural-vectors/ and https://www.naturalearthdata.com/downloads/50m-cultural-vectors/
