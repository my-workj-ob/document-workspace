package tests

import (
	"testing"

	"ai-chat-backend/internal/files"
)

func TestExtractEntitiesFromChunks(t *testing.T) {
	chunks := []files.RetrievalResult{
		{
			FileID:       "f-1",
			Filename:     "financial_report.pdf",
			PageNumber:   1,
			SectionTitle: "Bo'lim 1. Asosiy ko'rsatkichlar",
			Snippet:      "Kompaniya 2024-yil 15-mart holatiga ko'ra daromadni 25% ga oshirdi. Jami $1,500,000 foyda ko'rildi.\n| Yil | Daromad |\n| 2023 | $1,200,000 |\n| 2024 | $1,500,000 |",
		},
	}

	entities := files.ExtractEntitiesFromChunks(chunks)
	if len(entities.Dates) == 0 {
		t.Errorf("Expected extracted dates, got 0")
	}
	if len(entities.Numbers) == 0 {
		t.Errorf("Expected extracted numbers, got 0")
	}
	if len(entities.Tables) == 0 {
		t.Errorf("Expected extracted table, got 0")
	}
}

func TestGenerateSuggestedQuestions(t *testing.T) {
	chunks := []files.RetrievalResult{
		{
			FileID:       "f-1",
			Filename:     "audit.pdf",
			PageNumber:   3,
			SectionTitle: "Xavf-xatarlar tahlili",
			Snippet:      "Loyiha bo'yicha asosiy xavf kiberxavfsizlik va ma'lumotlar yo'qolishi hisoblanadi.",
		},
	}

	questions := files.GenerateSuggestedQuestions("uz", "buni tushuntirib ber", chunks, "critical_review")
	if len(questions) < 3 {
		t.Errorf("Expected at least 3 suggested questions, got %d", len(questions))
	}

	ruQuestions := files.GenerateSuggestedQuestions("ru", "объясни", chunks, "deep_analysis")
	if len(ruQuestions) < 3 {
		t.Errorf("Expected at least 3 Russian suggested questions, got %d", len(ruQuestions))
	}
}

func TestBuildAnalysisModePrompt(t *testing.T) {
	modes := []string{"quick_summary", "critical_review", "academic", "legal", "financial", "comparison", "deep_analysis"}
	for _, m := range modes {
		p := files.BuildAnalysisModePrompt("uz", m)
		if p == "" {
			t.Errorf("Expected non-empty prompt for mode %s", m)
		}
	}
}
