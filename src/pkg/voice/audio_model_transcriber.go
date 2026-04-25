package voice

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/sipeed/picoclaw/pkg/config"
	"github.com/sipeed/picoclaw/pkg/logger"
	"github.com/sipeed/picoclaw/pkg/providers"
	"github.com/sipeed/picoclaw/pkg/providers/common"
	"github.com/sipeed/picoclaw/pkg/utils"
)

type AudioModelTranscriber struct {
	provider providers.LLMProvider
	modelID  string
	prompt   string
	language string
	apiKey   string
	apiBase  string
	client   *http.Client
}

const (
	defaultTranscriptionPrompt = "Transcribe this audio."
)

func NewAudioModelTranscriber(modelCfg *config.ModelConfig, voiceCfg config.VoiceConfig) *AudioModelTranscriber {
	if modelCfg == nil {
		return nil
	}

	logger.DebugCF("voice", "Creating audio model transcriber", map[string]any{
		"has_api_key": modelCfg.APIKey() != "",
		"api_base":    modelCfg.APIBase,
		"model":       modelCfg.Model,
	})

	provider, modelID, err := providers.CreateProviderFromConfig(modelCfg)
	if err != nil {
		logger.ErrorCF("voice", "Failed to create audio model provider", map[string]any{"error": err})
		return nil
	}

	return &AudioModelTranscriber{
		provider: provider,
		modelID:  modelID,
		prompt:   defaultPromptForLanguage(voiceCfg.Language),
		language: strings.TrimSpace(voiceCfg.Language),
		apiKey:   modelCfg.APIKey(),
		apiBase:  strings.TrimRight(modelCfg.APIBase, "/"),
		client:   common.NewHTTPClient(modelCfg.Proxy),
	}
}

func defaultPromptForLanguage(language string) string {
	switch strings.ToLower(strings.TrimSpace(language)) {
	case "vi":
		return "Hay phien am chinh xac bang tieng Viet, giu nguyen noi dung goc, khong dich sang tieng Anh."
	default:
		return defaultTranscriptionPrompt
	}
}

func (t *AudioModelTranscriber) Transcribe(ctx context.Context, audioFilePath string) (*TranscriptionResponse, error) {
	if usesAudioTranscriptionsEndpoint(t.modelID) {
		return t.transcribeViaAudioAPI(ctx, audioFilePath)
	}

	return t.transcribeViaChat(ctx, audioFilePath)
}

func (t *AudioModelTranscriber) transcribeViaChat(
	ctx context.Context,
	audioFilePath string,
) (*TranscriptionResponse, error) {
	logger.InfoCF("voice", "Starting audio model transcription", map[string]any{
		"audio_file": audioFilePath,
		"model":      t.modelID,
	})

	audioBytes, err := os.ReadFile(audioFilePath)
	if err != nil {
		logger.ErrorCF("voice", "Failed to read audio file", map[string]any{"path": audioFilePath, "error": err})
		return nil, fmt.Errorf("failed to read audio file: %w", err)
	}

	format, err := utils.AudioFormat(audioFilePath)
	if err != nil {
		logger.ErrorCF("voice", "Failed to detect audio format", map[string]any{"path": audioFilePath, "error": err})
		return nil, err
	}

	resp, err := t.provider.Chat(ctx, []providers.Message{
		{
			Role:    "user",
			Content: t.prompt,
			Media: []string{
				fmt.Sprintf("data:audio/%s;base64,%s", format, base64.StdEncoding.EncodeToString(audioBytes)),
			},
		},
	}, nil, t.modelID, map[string]any{
		"temperature": 0,
	})
	if err != nil {
		logger.ErrorCF("voice", "Audio model transcription request failed", map[string]any{"error": err})
		return nil, fmt.Errorf("transcription request failed: %w", err)
	}

	text := strings.TrimSpace(resp.Content)
	logger.InfoCF("voice", "Audio model transcription completed successfully", map[string]any{
		"text_length":           len(text),
		"transcription_preview": utils.Truncate(text, 50),
	})

	return &TranscriptionResponse{Text: text}, nil
}

func (t *AudioModelTranscriber) transcribeViaAudioAPI(
	ctx context.Context,
	audioFilePath string,
) (*TranscriptionResponse, error) {
	logger.InfoCF("voice", "Starting transcription via audio API", map[string]any{
		"audio_file": audioFilePath,
		"model":      t.modelID,
	})

	audioFile, err := os.Open(audioFilePath)
	if err != nil {
		logger.ErrorCF("voice", "Failed to open audio file", map[string]any{"path": audioFilePath, "error": err})
		return nil, fmt.Errorf("failed to open audio file: %w", err)
	}
	defer audioFile.Close()

	var requestBody bytes.Buffer
	writer := multipart.NewWriter(&requestBody)

	part, err := writer.CreateFormFile("file", filepath.Base(audioFilePath))
	if err != nil {
		logger.ErrorCF("voice", "Failed to create form file", map[string]any{"error": err})
		return nil, fmt.Errorf("failed to create form file: %w", err)
	}
	if _, err := io.Copy(part, audioFile); err != nil {
		logger.ErrorCF("voice", "Failed to copy file content", map[string]any{"error": err})
		return nil, fmt.Errorf("failed to copy file content: %w", err)
	}

	if err := writer.WriteField("model", t.modelID); err != nil {
		logger.ErrorCF("voice", "Failed to write model field", map[string]any{"error": err})
		return nil, fmt.Errorf("failed to write model field: %w", err)
	}
	if strings.TrimSpace(t.language) != "" {
		if err := writer.WriteField("language", strings.TrimSpace(t.language)); err != nil {
			logger.ErrorCF("voice", "Failed to write language field", map[string]any{"error": err})
			return nil, fmt.Errorf("failed to write language field: %w", err)
		}
	}
	if err := writer.WriteField("response_format", "json"); err != nil {
		logger.ErrorCF("voice", "Failed to write response_format field", map[string]any{"error": err})
		return nil, fmt.Errorf("failed to write response_format field: %w", err)
	}
	if err := writer.Close(); err != nil {
		logger.ErrorCF("voice", "Failed to close multipart writer", map[string]any{"error": err})
		return nil, fmt.Errorf("failed to close multipart writer: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", t.apiBase+"/audio/transcriptions", &requestBody)
	if err != nil {
		logger.ErrorCF("voice", "Failed to create request", map[string]any{"error": err})
		return nil, fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("Content-Type", writer.FormDataContentType())
	if t.apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+t.apiKey)
	}

	resp, err := t.client.Do(req)
	if err != nil {
		logger.ErrorCF("voice", "Failed to send audio API request", map[string]any{"error": err})
		return nil, fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		logger.ErrorCF("voice", "Failed to read audio API response", map[string]any{"error": err})
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		logger.ErrorCF("voice", "Audio API error", map[string]any{
			"status_code": resp.StatusCode,
			"response":    string(body),
		})
		return nil, fmt.Errorf("audio API error (status %d): %s", resp.StatusCode, string(body))
	}

	var result TranscriptionResponse
	if err := json.Unmarshal(body, &result); err != nil {
		logger.ErrorCF("voice", "Failed to unmarshal audio API response", map[string]any{"error": err})
		return nil, fmt.Errorf("failed to unmarshal response: %w", err)
	}

	result.Text = strings.TrimSpace(result.Text)
	logger.InfoCF("voice", "Audio API transcription completed successfully", map[string]any{
		"text_length":           len(result.Text),
		"transcription_preview": utils.Truncate(result.Text, 50),
	})

	return &result, nil
}

func usesAudioTranscriptionsEndpoint(modelID string) bool {
	return strings.Contains(strings.ToLower(strings.TrimSpace(modelID)), "-transcribe")
}

func (t *AudioModelTranscriber) Name() string {
	return "audio-model"
}
