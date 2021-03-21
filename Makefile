run-docs: ## Run in development mode
	cd docs && hugo serve -D

docs: ## Build the site
	cd docs && hugo -t hermit -d public --gc --minify --cleanDestinationDir
