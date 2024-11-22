import fs from "fs";
import path from "path";
import { generateFileName } from "../modules/commonUtils";
import {
  parseHeaders,
  Header,
  findHeaderBeforePosition,
} from "../modules/headerUtils";

const testFilePath = path.join(__dirname, "../tests/testfile.md");
const testFileContent = fs.readFileSync(testFilePath, "utf-8");
const headers: Header[] = parseHeaders(testFileContent);

describe("commonUtils", () => {
  describe("generateFileName", () => {
    it("should generate a correct filename", () => {
      const result = generateFileName("testfile", 1, "Internal Communication");
      expect(result).toBe("testfile-01-internal-communication.png");
    });

    it("should handle special characters in heading", () => {
      const result = generateFileName("testfile", 2, "CI/CD Pipeline");
      expect(result).toBe("testfile-02-cicd-pipeline.png");
    });

    it("should pad single-digit numbers with a leading zero", () => {
      const result = generateFileName("testfile", 9, "Network Architecture");
      expect(result).toBe("testfile-09-network-architecture.png");
    });

    it("should not pad two-digit numbers", () => {
      const result = generateFileName("testfile", 10, "Database Schema");
      expect(result).toBe("testfile-10-database-schema.png");
    });
  });
});
