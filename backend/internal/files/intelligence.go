package files

import (
	"fmt"
	"regexp"
	"strings"
)

// ExtractedEntities holds structured entities extracted from documents.
type ExtractedEntities struct {
	Dates    []string `json:"dates"`
	Numbers  []string `json:"numbers"`
	Entities []string `json:"entities"`
	Tables   []string `json:"tables"`
}

var (
	dateRe   = regexp.MustCompile(`(?i)\b(\d{1,2}[-/.](?:\d{1,2}|yanvar|fevral|mart|aprel|may|iyun|iyul|avgust|sentabr|oktabr|noyabr|dekabr|january|february|march|april|may|june|july|august|september|october|november|december|\w+)[-/.](?:\d{2,4})|\d{4}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12]\d|3[01])|(?:19|20)\d{2}(?:-(?:yil|yildan|yilgacha|йил))?)\b`)
	numRe    = regexp.MustCompile(`(?i)\b(?:\$|€|£|UZS|so'm|сум)?\s*\d{1,3}(?:[ ,.]\d{3})*(?:[.,]\d+)?\s*(?:%|mln|milliard|ming|usd|dollar|so'm|сум|тыс|млн|млрд|k|m|b)?\b`)
	tableRe  = regexp.MustCompile(`(?m)^\|.*\|.*\|.*$`)
	entityRe = regexp.MustCompile(`(?m)^(?:Bo'lim|Bob|Slayd|Jadval|Modda|Qoida|Section|Chapter|Slide|Table|Article)\s*[\d.:]+[^\n]*`)
)

// ExtractEntitiesFromChunks extracts structured facts, dates, numbers, and detected tables from retrieved snippets.
func ExtractEntitiesFromChunks(chunks []RetrievalResult) ExtractedEntities {
	seenDates := make(map[string]bool)
	seenNums := make(map[string]bool)
	seenEnts := make(map[string]bool)
	var dates []string
	var numbers []string
	var entities []string
	var tables []string

	for _, c := range chunks {
		text := c.Snippet

		// Extract dates
		matches := dateRe.FindAllString(text, 10)
		for _, m := range matches {
			clean := strings.TrimSpace(m)
			if len(clean) >= 4 && !seenDates[clean] {
				seenDates[clean] = true
				dates = append(dates, clean)
				if len(dates) >= 8 {
					break
				}
			}
		}

		// Extract financial & quantitative figures
		nMatches := numRe.FindAllString(text, 15)
		for _, nm := range nMatches {
			clean := strings.TrimSpace(nm)
			if len(clean) >= 2 && !seenNums[clean] {
				// Filter out single bare digits
				if len(clean) == 1 && clean >= "0" && clean <= "9" {
					continue
				}
				seenNums[clean] = true
				numbers = append(numbers, clean)
				if len(numbers) >= 8 {
					break
				}
			}
		}

		// Extract section entities / headers
		if c.SectionTitle != "" && !seenEnts[c.SectionTitle] {
			seenEnts[c.SectionTitle] = true
			entities = append(entities, c.SectionTitle)
		}
		eMatches := entityRe.FindAllString(text, 5)
		for _, em := range eMatches {
			clean := strings.TrimSpace(em)
			if len(clean) > 3 && !seenEnts[clean] {
				seenEnts[clean] = true
				entities = append(entities, clean)
				if len(entities) >= 8 {
					break
				}
			}
		}

		// Detect markdown tables
		if tableRe.MatchString(text) {
			lines := strings.Split(text, "\n")
			var tableBuf strings.Builder
			inTable := false
			for _, l := range lines {
				trimmed := strings.TrimSpace(l)
				if strings.HasPrefix(trimmed, "|") && strings.HasSuffix(trimmed, "|") {
					inTable = true
					tableBuf.WriteString(trimmed + "\n")
				} else if inTable {
					break
				}
			}
			tStr := strings.TrimSpace(tableBuf.String())
			if tStr != "" && len(tables) < 3 {
				tables = append(tables, tStr)
			}
		}
	}

	return ExtractedEntities{
		Dates:    dates,
		Numbers:  numbers,
		Entities: entities,
		Tables:   tables,
	}
}

// GenerateSuggestedQuestions crafts 3-5 context-aware suggested follow-up questions based on extracted topics.
func GenerateSuggestedQuestions(locale string, query string, chunks []RetrievalResult, mode string) []string {
	loc := strings.ToLower(locale)
	hasTables := false
	hasRisks := false
	var topics []string

	for _, c := range chunks {
		low := strings.ToLower(c.Snippet)
		if strings.Contains(low, "xavf") || strings.Contains(low, "risk") || strings.Contains(low, "muammo") || strings.Contains(low, "kamchilik") {
			hasRisks = true
		}
		if strings.Contains(low, "|") || strings.Contains(low, "jadval") || strings.Contains(low, "table") {
			hasTables = true
		}
		if c.SectionTitle != "" && len(topics) < 3 {
			topics = append(topics, c.SectionTitle)
		}
	}

	var questions []string

	switch loc {
	case "ru":
		questions = append(questions, "Каковы главные выводы и ключевые тезисы документа?")
		if len(topics) > 0 {
			questions = append(questions, fmt.Sprintf("Подробнее раскройте тему: %s", topics[0]))
		}
		if hasRisks || mode == "critical_review" {
			questions = append(questions, "Какие потенциальные риски и ограничения упоминаются?")
		}
		if hasTables || mode == "financial" {
			questions = append(questions, "Покажите структурированную сводку данных и показателей.")
		}
		questions = append(questions, "Какие практические решения можно принять на основе этого документа?")

	case "uz":
		questions = append(questions, "Hujjatning eng muhim xulosalari va asosiy tezislari nimalardan iborat?")
		if len(topics) > 0 {
			questions = append(questions, fmt.Sprintf("\"%s\" bo'limi haqida batafsil ma'lumot bering", topics[0]))
		}
		if hasRisks || mode == "critical_review" {
			questions = append(questions, "Hujjatda qanday xavf-xatarlar yoki cheklovlar mavjud?")
		}
		if hasTables || mode == "financial" {
			questions = append(questions, "Hujjatdagi raqamlar va jadvalli ma'lumotlarni umumlashtirib bering.")
		}
		questions = append(questions, "Ushbu tahlil asosida qanday amaliy qarorlar qabul qilish mumkin?")

	default: // en
		questions = append(questions, "What are the most critical findings and executive takeaways?")
		if len(topics) > 0 {
			questions = append(questions, fmt.Sprintf("Can you expand on the section: \"%s\"?", topics[0]))
		}
		if hasRisks || mode == "critical_review" {
			questions = append(questions, "What potential risks, contradictions, or gaps are identified?")
		}
		if hasTables || mode == "financial" {
			questions = append(questions, "Provide a structured breakdown of the key metrics and tables.")
		}
		questions = append(questions, "What actionable decisions can be made based on this document?")
	}

	if len(questions) > 4 {
		questions = questions[:4]
	}
	return questions
}

// BuildAnalysisModePrompt returns prompt extensions tailoring LLM focus for specific analysis modes.
func BuildAnalysisModePrompt(locale string, mode string) string {
	cleanMode := strings.ToLower(strings.TrimSpace(mode))
	switch cleanMode {
	case "quick_summary":
		return "TAHLIL REJIMI: TEZKOR XULOSA (QUICK SUMMARY).\nAsosiy g'oyalarni qisqa, ixcham va tushunarli punktlar shaklida bayon qiling. Ortiqcha tafsilotlarsiz faqat eng muhim xulosalarni bering."
	case "critical_review":
		return "TAHLIL REJIMI: TANQIDIY TAHLIL (CRITICAL REVIEW).\nHujjatdagi dalillarni xolisona tahlil qiling: kuchli va zaif tomonlar, ehtimoliy ziddiyatlar, to'liq yoritilmagan yoki yetishmayotgan ma'lumotlar, hamda yuzaga kelishi mumkin bo'lgan xatarlarni aniq ko'rsating."
	case "academic":
		return "TAHLIL REJIMI: ILMIY TADQIQOT (ACADEMIC RESEARCH).\nIlmiy metodologiya, nazariy asoslar, tushunchalar o'rtasidagi mantiqiy bog'liqliklar va dalillarga asoslangan chuqur akademik uslubda yoritib bering."
	case "legal":
		return "TAHLIL REJIMI: HUQUQIY TAHLIL (LEGAL REVIEW).\nHujjatdagi huquqiy shartlar, majburiyatlar, muddatlar va javobgarlik moddalarini tartib bilan ko'rsating. (Eslatma: Bu rasmiy yuridik maslahat emas, tahliliy ko'rib chiqish hisoblanadi)."
	case "financial":
		return "TAHLIL REJIMI: MOLIYAVIY TAHLIL (FINANCIAL ANALYSIS).\nHujjatdagi barcha moliyaviy ko'rsatkichlar, daromad/xarajatlar, hisob-kitoblar, foizlar va dinamikani aniq jadvallar hamda raqamlar bilan jamlang."
	case "comparison":
		return "TAHLIL REJIMI: HUJJATLARNI TAQQOSLASH (DOCUMENT COMPARISON).\nBir nechta hujjatlar yoki bo'limlar o'rtasidagi o'xshashliklar, asosiy farqlar, ziddiyatli raqamlar yoki yondashuvlarni aniq solishtirib jadval yoki punktlarda ko'rsating."
	default:
		return "TAHLIL REJIMI: CHUQUR TAHLIL (DEEP ANALYSIS).\nHujjatning barcha muhim jihatlarini tizimli, dalillarga tayangan holda to'liq va professional darajada tahlil qiling."
	}
}
