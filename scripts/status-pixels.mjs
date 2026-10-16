import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { inflateSync } from "node:zlib";

const colors = { blue: [76, 158, 255], green: [76, 187, 112], yellow: [227, 192, 75], red: [239, 107, 115] };

function decode(bytes) {
  assert.ok(bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])), "Expected a native PNG screenshot");
  const chunks = [];
  let width, height;
  for (let offset = 8; offset < bytes.length;) {
    const length = bytes.readUInt32BE(offset);
    const type = bytes.toString("ascii", offset + 4, offset + 8);
    const data = bytes.subarray(offset + 8, offset + 8 + length);
    if (type === "IHDR") {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      assert.deepEqual([...data.subarray(8)], [8, 6, 0, 0, 0], "Native screenshot must be noninterlaced RGBA8");
    } else if (type === "IDAT") chunks.push(data);
    offset += length + 12;
    if (type === "IEND") break;
  }
  assert.ok(width && height, "Missing PNG dimensions");
  const stride = width * 4;
  const source = inflateSync(Buffer.concat(chunks));
  assert.equal(source.length, (stride + 1) * height, "PNG pixel data length mismatch");
  const pixels = Buffer.alloc(stride * height);
  for (let y = 0; y < height; y++) {
    const row = y * stride, start = y * (stride + 1), filter = source[start];
    assert.ok(filter <= 4, "Unknown PNG row filter");
    for (let x = 0; x < stride; x++) {
      const left = x >= 4 ? pixels[row + x - 4] : 0;
      const up = y ? pixels[row - stride + x] : 0;
      const corner = y && x >= 4 ? pixels[row - stride + x - 4] : 0;
      let prediction = 0;
      if (filter === 1) prediction = left;
      if (filter === 2) prediction = up;
      if (filter === 3) prediction = Math.floor((left + up) / 2);
      if (filter === 4) {
        const p = left + up - corner;
        const a = Math.abs(p - left), b = Math.abs(p - up), c = Math.abs(p - corner);
        prediction = a <= b && a <= c ? left : b <= c ? up : corner;
      }
      pixels[row + x] = source[start + x + 1] + prediction;
    }
  }
  return { width, height, pixels };
}

export async function statusPixels(shot, tabs) {
  const [bytes, layoutText] = await Promise.all([readFile(shot.png), readFile(shot.layout, "utf8")]);
  const { width, height, pixels } = decode(bytes);
  const layout = JSON.parse(layoutText);
  const rows = layout.elements.filter(item => item.visible && /^(button\.nav-row|button\.tt)(\.|$)/.test(item.path.split(">").at(-1)));
  assert.equal(rows.length, tabs.length, "Visible tab rows must match the owned window's tabs");
  const scale = layout.viewport.deviceScaleFactor;
  return Object.fromEntries(rows.map((row, index) => {
    const [x, y, w, h] = row.rect;
    const cx = Math.round((x + w - 13.5) * scale), cy = Math.round((y + h / 2) * scale);
    const matches = Object.fromEntries(Object.keys(colors).map(name => [name, 0]));
    for (let px = cx - 2; px <= cx + 2; px++) for (let py = cy - 2; py <= cy + 2; py++) {
      assert.ok(px >= 0 && px < width && py >= 0 && py < height, "Status dot sampling outside screenshot");
      const offset = (py * width + px) * 4;
      for (const [name, rgb] of Object.entries(colors)) {
        if (rgb.every((channel, i) => Math.abs(channel - pixels[offset + i]) < 12)) matches[name]++;
      }
    }
    let color = Object.keys(colors).find(name => matches[name] >= 10) ?? null;
    const original = layout.elements.find(item => item.visible && item.nth.startsWith(row.nth + ">") && item.path.split(">").at(-1) === "span.tn-tc");
    if (!color && original && tabs[index].color) {
      const [ox, oy, ow, oh] = original.rect;
      const px = Math.round((ox + ow / 2) * scale), py = Math.round((oy + oh / 2) * scale);
      const rgb = original.backgroundColor.match(/^rgb\((\d+), (\d+), (\d+)\)$/)?.slice(1).map(Number);
      const offset = (py * width + px) * 4;
      if (rgb && rgb.every((channel, i) => Math.abs(channel - pixels[offset + i]) < 12)) color = tabs[index].color;
    }
    return [tabs[index].id, { color, pixel: [cx, cy], matches }];
  }));
}
