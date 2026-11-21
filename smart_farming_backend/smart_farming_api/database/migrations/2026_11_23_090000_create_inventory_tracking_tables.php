<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('resource_purchases', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('resource_id')->nullable()->constrained('resources')->nullOnDelete();
            $table->string('resource_name');
            $table->string('resource_unit', 50);
            $table->decimal('qty', 12, 2);
            $table->decimal('unit_price', 15, 2);
            $table->decimal('total_cost', 15, 2);
            $table->string('supplier')->nullable();
            $table->text('notes')->nullable();
            $table->date('purchased_at');
            $table->string('status', 20)->default('disetujui');
            $table->foreignId('requested_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('decided_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('decided_at')->nullable();
            $table->string('reject_reason', 500)->nullable();
            $table->timestamps();

            $table->index(['company_id', 'status']);
        });

        Schema::create('tool_incidents', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('tool_id')->constrained('tools')->cascadeOnDelete();
            $table->foreignId('tool_unit_id')->nullable()->constrained('tool_units')->nullOnDelete();
            $table->string('unit_code')->nullable();
            $table->foreignId('task_id')->nullable()->constrained('tasks')->nullOnDelete();
            $table->string('kind', 10);
            $table->string('status', 15)->default('terbuka');
            $table->text('notes')->nullable();
            $table->foreignId('reported_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('resolution', 15)->nullable();
            $table->decimal('resolution_cost', 15, 2)->nullable();
            $table->text('resolution_notes')->nullable();
            $table->foreignId('resolved_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('resolved_at')->nullable();
            $table->timestamps();

            $table->index(['company_id', 'status']);
        });

        Schema::table('task_tools', function (Blueprint $table) {
            $table->unsignedInteger('damaged_qty')->default(0)->after('lost_qty');
        });

        Schema::table('finances', function (Blueprint $table) {
            $table->foreignId('resource_purchase_id')->nullable()->after('payroll_id')->constrained('resource_purchases')->nullOnDelete();
            $table->foreignId('tool_incident_id')->nullable()->after('resource_purchase_id')->constrained('tool_incidents')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('finances', function (Blueprint $table) {
            $table->dropConstrainedForeignId('tool_incident_id');
            $table->dropConstrainedForeignId('resource_purchase_id');
        });

        Schema::table('task_tools', function (Blueprint $table) {
            $table->dropColumn('damaged_qty');
        });

        Schema::dropIfExists('tool_incidents');
        Schema::dropIfExists('resource_purchases');
    }
};
