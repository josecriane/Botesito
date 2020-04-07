REBAR3 = rebar3

.PHONY: analysis build test

all: test analysis

analysis:
	@$(REBAR3) do xref, dialyzer

clean:
	@$(REBAR3) clean --all
	rm -rf _build

test:
	@$(REBAR3) do ct --cover --config apps/botesito/test/conf/test.conf, cover -vm 100

release:
	@$(REBAR3) release











