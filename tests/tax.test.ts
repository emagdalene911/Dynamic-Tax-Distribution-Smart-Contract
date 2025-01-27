import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const government = accounts.get("wallet_1")!;
const taxpayer = accounts.get("wallet_2")!;

describe("tax contract", () => {
    it("allows taxpayers to pay tax", () => {
        const payTaxCall = simnet.callPublicFn("tax", "pay-tax", [], taxpayer);
        expect(payTaxCall.result).toBeOk(Cl.bool(true));
    });

    it("allows government to allocate funds", () => {
        const department = "EDUCATION";
        const amount = 1000;
        
        const allocateCall = simnet.callPublicFn(
            "tax", 
            "allocate-funds",
            [Cl.stringAscii(department), Cl.uint(amount)],
            government
        );
        expect(allocateCall.result).toBeOk(Cl.bool(true));

        const getAllocationCall = simnet.callReadOnlyFn(
            "tax",
            "get-department-allocation",
            [Cl.stringAscii(department)],
            government
        );
        expect(getAllocationCall.result).toBeOk(Cl.uint(amount));
    });
    it("tracks treasury balance", () => {
        const balanceCall = simnet.callReadOnlyFn(
            "tax",
            "get-treasury-balance",
            [],
            government
        );
        expect(balanceCall.result).toBeDefined();
    });
});
