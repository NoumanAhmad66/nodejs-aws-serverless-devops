const { test, expect } = require("@jest/globals");
const { handler } = require("./handler");

test("Lambda returns hello message", async () => {
  const event = {};
  const result = await handler(event);
  expect(result.statusCode).toBe(200);
  expect(JSON.parse(result.body).message).toBe("Hello from AWS Lambda 🚀");
});
