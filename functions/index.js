const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const fetch = require("node-fetch");

// ✅ Secret
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

exports.askAI = onRequest(
  { secrets: [GEMINI_API_KEY] },
  async (req, res) => {
    try {
      if (req.method !== "POST") {
        return res.status(405).send("Method Not Allowed");
      }

      const prompt = req.body.prompt;

      if (!prompt) {
        return res.status(400).send({ error: "Prompt required" });
      }

      // ✅ KEY define FIRST
      const apiKey = GEMINI_API_KEY.value();

      // ✅ debug (correct place)
      console.log("API KEY:", apiKey);

      if (!apiKey) {
        return res.status(500).send({ error: "API key missing" });
      }

      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            contents: [
              {
                parts: [{ text: prompt }],
              },
            ],
          }),
        }
      );

      const data = await response.json();

      if (data.error) {
        return res.status(500).send({ error: data.error.message });
      }

      const reply =
        data.candidates?.[0]?.content?.parts?.[0]?.text || "No response";

      res.send({
        success: true,
        reply: reply,
      });
    } catch (error) {
      console.error("ERROR:", error);
      res.status(500).send({ error: error.toString() });
    }
  }
);
