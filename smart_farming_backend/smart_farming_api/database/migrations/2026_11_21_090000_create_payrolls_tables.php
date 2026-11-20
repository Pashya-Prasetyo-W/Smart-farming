<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('payrolls', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->date('period_start');
            $table->date('period_end');
            $table->string('status', 20)->default('draf');
            $table->decimal('total_amount', 15, 2)->default(0);
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('approved_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('approved_at')->nullable();
            $table->timestamp('paid_at')->nullable();
            $table->timestamps();

            $table->index(['company_id', 'period_start', 'period_end']);
        });

        Schema::create('payroll_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('payroll_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('wage_type', 20)->nullable();
            $table->decimal('rate', 15, 2)->default(0);
            $table->unsignedInteger('units')->default(0);
            $table->decimal('base_amount', 15, 2)->default(0);
            $table->decimal('allowances_total', 15, 2)->default(0);
            $table->decimal('total_amount', 15, 2)->default(0);
            $table->json('details')->nullable();
            $table->string('note')->nullable();
            $table->timestamps();

            $table->unique(['payroll_id', 'user_id']);
        });

        Schema::table('attendances', function (Blueprint $table) {
            $table->foreignId('payroll_id')->nullable()->after('is_final')->constrained('payrolls')->nullOnDelete();
        });

        Schema::table('task_reports', function (Blueprint $table) {
            $table->foreignId('payroll_id')->nullable()->after('is_final')->constrained('payrolls')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('task_reports', function (Blueprint $table) {
            $table->dropConstrainedForeignId('payroll_id');
        });

        Schema::table('attendances', function (Blueprint $table) {
            $table->dropConstrainedForeignId('payroll_id');
        });

        Schema::dropIfExists('payroll_items');
        Schema::dropIfExists('payrolls');
    }
};
