const openAIAPIKey = process.env.OPENAI_API_KEY;

if (!openAIAPIKey) {
  throw new Error("OPENAI_API_KEY is not configured.");
}

export const openAIModelConfig = {
  transcribeModel: "gpt-transcribe",
  textModel: process.env.OPENAI_TEXT_MODEL ?? "gpt-5-mini"
};

export async function transcribeAudio(audio: File) {
  const form = new FormData();
  form.set("model", openAIModelConfig.transcribeModel);
  form.append("languages[]", "zh");
  form.append("keywords[]", "怎么写");
  form.append("keywords[]", "我想学");
  form.append("keywords[]", "拼音");
  form.set("prompt", "儿童中文写字学习 App。用户通常会问：我想去公园怎么写、苹果怎么写、这个字怎么读。");
  form.set("response_format", "json");
  form.set("file", audio);

  const response = await fetch("https://api.openai.com/v1/audio/transcriptions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${openAIAPIKey}`
    },
    body: form
  });

  const payload = await response.json();
  if (!response.ok) {
    throw new Error(payload?.error?.message ?? "OpenAI 语音识别失败。");
  }

  return String(payload.text ?? "").trim();
}

export async function extractTargetText(transcript: string) {
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${openAIAPIKey}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model: openAIModelConfig.textModel,
      reasoning: { effort: "minimal" },
      max_output_tokens: 80,
      input: [
        {
          role: "system",
          content: [
            {
              type: "input_text",
              text:
                "你只提取孩子想学习书写的中文内容。去掉“怎么写”“我想学”“请问”等询问语，但不要删掉目标句子本身的词。例：用户说“我想去公园怎么写”，target_text 是“我想去公园”；用户说“我想学苹果怎么写”，target_text 是“苹果”。只输出 schema JSON。"
            }
          ]
        },
        {
          role: "user",
          content: [{ type: "input_text", text: transcript }]
        }
      ],
      text: {
        format: {
          type: "json_schema",
          name: "learning_text_extraction",
          strict: true,
          schema: {
            type: "object",
            additionalProperties: false,
            properties: {
              target_text: {
                type: "string",
                description: "用户真正想显示并学习书写的中文，可以是一个字、词语或一句话。"
              }
            },
            required: ["target_text"]
          }
        }
      }
    })
  });

  const payload = await response.json();
  if (!response.ok) {
    throw new Error(payload?.error?.message ?? "OpenAI 文本提取失败。");
  }

  const outputText = findOutputText(payload);
  if (!outputText) {
    throw new Error("OpenAI 响应中没有找到可解析的文本。");
  }

  const parsed = JSON.parse(outputText) as { target_text?: string };
  return String(parsed.target_text ?? "").trim();
}

function findOutputText(value: unknown): string | undefined {
  if (!value) return undefined;
  if (Array.isArray(value)) {
    for (const item of value) {
      const text = findOutputText(item);
      if (text) return text;
    }
    return undefined;
  }
  if (typeof value === "object") {
    const record = value as Record<string, unknown>;
    if (record.type === "output_text" && typeof record.text === "string") {
      return record.text;
    }
    if (typeof record.output_text === "string") {
      return record.output_text;
    }
    for (const item of Object.values(record)) {
      const text = findOutputText(item);
      if (text) return text;
    }
  }
  return undefined;
}
