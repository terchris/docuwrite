import fs from "fs";
import path from "path";
import {
  parseHeaders,
  findHeaderBeforePosition,
  Header,
} from "../modules/headerUtils";

const testFilePath = path.join(__dirname, "../tests/testfile.md");
const testFileContent = fs.readFileSync(testFilePath, "utf-8");
const headers: Header[] = parseHeaders(testFileContent);

const expectedHeadersPath = path.join(__dirname, "../tests/headers.json");
const expectedHeaders: Header[] = JSON.parse(
  fs.readFileSync(expectedHeadersPath, "utf-8")
);

describe("headerUtils", () => {
  describe("parseHeaders", () => {
    it("should correctly parse headers from the test file", () => {
      expect(headers).toEqual(expectedHeaders);
    });
  });

  describe("findHeaderBeforePosition", () => {
    it("should return the correct header text for a given position", () => {
      const nearestHeader = findHeaderBeforePosition(headers, 1240);
      expect(nearestHeader).toBe("Internal Communication");
    });

    it("should return the last header text for a position after all headers", () => {
      const nearestHeader = findHeaderBeforePosition(headers, 100000000);
      expect(nearestHeader).toBe("Network Packet Structure");
    });
  });
});
