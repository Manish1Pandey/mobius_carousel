# Bird photographs — credits and licences

All six photographs are **public domain (Creative Commons CC0 1.0 Universal)**.
No attribution is legally required; it is given here as a courtesy and as proof of
provenance. Each file was downloaded from Wikimedia Commons, cropped to 600x800
(3:4), re-encoded as JPEG (quality 88, progressive, EXIF and ICC metadata stripped).
No other alteration was made.

| File | Species | Author | Licence | Source (Wikimedia Commons file page) |
|---|---|---|---|---|
| `red_and_green_macaw.jpg` | Red-and-green macaw (*Ara chloropterus*) | Dcoetzee | CC0 1.0 (`{{cc-zero}}`) | https://commons.wikimedia.org/wiki/File:Green-winged_macaw_headshot_at_Cougar_Mountain_Zoological_Park.jpg |
| `chilean_flamingo.jpg` | Chilean flamingo (*Phoenicopterus chilensis*) | Carlota Vidal (Unsplash, `charlottephoto`) | CC0 1.0 (`{{Unsplash}}`, uploaded 2017-04-14, i.e. under the pre-2017-06-05 Unsplash CC0 terms) | https://commons.wikimedia.org/wiki/File:Flamingo_closeup_(Unsplash).jpg |
| `sun_conure.jpg` | Sun parakeet / sun conure (*Aratinga solstitialis*) | Daderot | CC0 1.0 (`{{self\|cc-zero}}`) | https://commons.wikimedia.org/wiki/File:Aratinga_solstitialis_-_Wilhelma_Zoo_-_Stuttgart,_Germany_-_DSC02174.jpg |
| `yellow_warbler.jpg` | Yellow warbler (*Setophaga petechia*), Galápagos | Wmpearl | CC0 1.0 (`{{self\|Cc-zero}}`) | https://commons.wikimedia.org/wiki/File:Setophaga_petechia,_Galapagos.jpg |
| `yellow_collared_lovebird.jpg` | Yellow-collared lovebird (*Agapornis personatus*) | Adam Kranz | CC0 1.0 (`{{Cc-zero}}`) | https://commons.wikimedia.org/wiki/File:Agapornis_personatus_42975356.jpg |
| `indian_peacock.jpg` | Indian peafowl (*Pavo cristatus*), male | Bernard Spragg. NZ | CC0 1.0 (`{{cc-zero}}`) | https://commons.wikimedia.org/wiki/File:Peacock_portrait._(8316435538).jpg |

Licence deed: https://creativecommons.org/publicdomain/zero/1.0/

## Dominant colours

| File | Dominant colour | Size |
|---|---|---|
| `red_and_green_macaw.jpg` | `#920D13` (red) | 86 KB |
| `chilean_flamingo.jpg` | `#C4847C` (pink) | 55 KB |
| `sun_conure.jpg` | `#A44E03` (orange) | 99 KB |
| `yellow_warbler.jpg` | `#B78F07` (yellow) | 115 KB |
| `yellow_collared_lovebird.jpg` | `#506435` (green) | 90 KB |
| `indian_peacock.jpg` | `#07207C` (blue) | 222 KB |

All files are 600x800 px; the folder totals ~676 KB.

### How these values were computed

Downscale the image so its longest side is <= 240 px, then discard every pixel that
is near-white, near-black or washed out (in HSV: `saturation < 0.30`, `value < 0.30`
or `value > 0.97`). Median-cut quantise the surviving pixels into 12 colours and take
the palette entry with the most pixels. Reference implementation:

```python
from PIL import Image
import colorsys, collections

def dominant(path, sat_min=0.30, v_min=0.30, v_max=0.97, k=12):
    im = Image.open(path).convert('RGB')
    im.thumbnail((240, 240))
    px = []
    for r, g, b in list(im.getdata()):
        _, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        if s < sat_min or v < v_min or v > v_max:
            continue
        px.append((r, g, b))
    buf = Image.new('RGB', (len(px), 1))
    buf.putdata(px)
    q = buf.quantize(colors=k, method=Image.Quantize.MEDIANCUT,
                     dither=Image.Dither.NONE)
    pal = q.getpalette()
    idx, _ = collections.Counter(q.getdata()).most_common(1)[0]
    return '#%02X%02X%02X' % tuple(pal[idx * 3:idx * 3 + 3])
```

**Tolerance note for the runtime extractor.** These hexes are the *exact* output of the
algorithm above on these *exact* files. A different implementation (different
downscale filter, bucket count, or saturation cut-off) will land on a neighbouring
shade of the same hue rather than on the identical value, so assert on hue family or
with a per-channel tolerance rather than on string equality. The two images with the
narrowest margin between the winning cluster and the runner-up are:

* `chilean_flamingo.jpg` — `#C4847C` (11%) vs `#E5AE97` (11%); both are the bird's pink.
* `indian_peacock.jpg` — `#07207C` (19%, the blue neck) vs `#585E2A` (14%, the olive
  tail-fan behind it). A materially different extractor could pick the olive here.

Every other image wins by a comfortable margin and all of its top clusters are in the
same hue family.
