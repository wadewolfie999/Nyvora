#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"

ROOT = File.expand_path("..", __dir__)

def fail_check(message)
  warn "architecture validation error: #{message}"
  exit 1
end

def run_command(*args)
  stdout, stderr, status = Open3.capture3(*args)
  fail_check("#{args.join(' ')} failed: #{stderr.strip}") unless status.success?

  stdout
end

required_files = %w[
  architecture/README.md
  architecture/CHANGE-CONTROL.md
  architecture/SUPERSESSION.md
  architecture/NYVORA-Architectural-Baseline-v1.0.1-corrected.docx
  records/NYVORA-BASELINE-ADOPTION-2026-08-30.md
  records/AB-0-EXECUTION-2026-08-30.md
  .github/CODEOWNERS
  docs/github-governance.md
  .github/workflows/ci.yml
  .github/workflows/repository-backup.yml
]
required_files.each do |relative|
  fail_check("missing #{relative}") unless File.file?(File.join(ROOT, relative))
end

docx = File.join(ROOT, "architecture/NYVORA-Architectural-Baseline-v1.0.1-corrected.docx")
entries = run_command("unzip", "-Z1", docx).lines.map(&:chomp)
fail_check("DOCX package is missing word/document.xml") unless entries.include?("word/document.xml")
fail_check("DOCX package is missing word/_rels/document.xml.rels") unless entries.include?("word/_rels/document.xml.rels")

media = entries.grep(%r{\Aword/media/})
fail_check("expected exactly two embedded figures, found #{media.length}") unless media == %w[word/media/image1.png word/media/image2.png]

xml = run_command("unzip", "-p", docx, "word/document.xml").force_encoding(Encoding::UTF_8)
fail_check("document XML is not valid UTF-8") unless xml.valid_encoding?

required_markers = [
  "NYV-AB-2026-01",
  "v1.0.1",
  "Adopted by owner instruction on 30 August 2026",
  "GitHub",
  "break-glass"
]
required_markers.each do |marker|
  fail_check("DOCX is missing required marker #{marker.inspect}") unless xml.include?(marker)
end

stale_markers = [
  "Wade",
  "Proposed for owner approval",
  "Ready for owner review",
  "Once approved",
  "Mac is the sole authority",
  "Radicle is required"
]
stale_markers.each do |marker|
  fail_check("stale DOCX marker remains: #{marker.inspect}") if xml.include?(marker)
end

ci = File.read(File.join(ROOT, ".github/workflows/ci.yml"))
fail_check("CI does not run architecture baseline validation") unless ci.include?("ruby scripts/validate_architecture_baseline.rb")

backup = File.read(File.join(ROOT, ".github/workflows/repository-backup.yml"))
%w[workflow_dispatch schedule git\ bundle git\ bundle\ verify actions/upload-artifact@v4 retention-days:].each do |marker|
  fail_check("backup workflow is missing #{marker.inspect}") unless backup.include?(marker)
end

governance = File.read(File.join(ROOT, "docs/github-governance.md"))
%w[development testing operational CODEOWNERS owner-only].each do |marker|
  fail_check("GitHub governance document is missing #{marker.inspect}") unless governance.include?(marker)
end

puts "Nyvora architecture baseline validation: PASS"
